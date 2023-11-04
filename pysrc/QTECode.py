import sys
import subprocess
import threading
from time import sleep
import os
import time
import io

from PyQt5.QtCore import *
from PyQt5.QtGui import *
from PyQt5.QtWidgets import *
from threading import Thread
from queue import Queue, Empty

from json import decoder

SYMBOL_KINDS = {
    1: "File",
    2: "Module",
    3: "Namespace",
    4: "Package",
    5: "Class",
    6: "Method",
    7: "Property",
    8: "Field",
    9: "Constructor",
    10: "Enum",
    11: "Interface",
    12: "Function",
    13: "Variable",
    14: "Constant",
    15: "String",
    16: "Number",
    17: "Boolean",
    18: "Array",
    19: "Object",
    20: "Key",
    21: "Null",
    22: "EnumMember",
    23: "Struct",
    24: "Event",
    25: "Operator",
    26: "TypeParameter",
}

class QCodeDocument:
    def __init__(self):
        self.file_path = ""
        self.file_content = ""
        self.symbols = []
        self.last_document_meta_info_request = time.time()
        self.edit_version = 0
        self.file_modified = False
        self.file_modified_time = 0
        self.file_opened = False
        self.file_saved = False

class Position():
    def __init__(self, line: int, character: int) -> None:
        self.line = line
        self.character = character

class Range():
    def __init__(self, start: Position, end: Position) -> None:
        self.start = start
        self.end = end

class DocumentSymbol():
    def __init__(self, name: str, kind: int, range: Range, selectionRange: dict, children: list):
        self.name = name
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange
        self.children = children

class QCodeEditor(QTextEdit):
    def __init__(self):
        super().__init__()

        # Vars
        self.open_documents = dict()
        self.focused_document = None
        self.lsp = None

        # Settings
        # self.setSizeAdjustPolicy(QAbstractScrollArea.AdjustIgnored)
        self.setStyleSheet("background-color: #161618; color: #F8F8FF;")
        # self.setTabStopWidth(20)
        # self.setTabChangesFocus(True)
        self.setAcceptRichText(False)
        self.setLineWrapMode(QTextEdit.NoWrap)
        # self.setAcceptDrops(False)
        self.setUndoRedoEnabled(True)
        # self.setLineWrapMode(QTextEdit.NoWrap)
        # self.setWordWrapMode(QTextOption.NoWrap)
        # self.setOverwriteMode(False)
        # self.setReadOnly(False)
        # self.setLineWrapColumnOrWidth(0)
        # self.setPlaceholderText("Code Editor")
        self.setFrameShape(QFrame.StyledPanel)
        self.setFrameShadow(QFrame.Plain)

        # Stretch the code editor to fill the working view
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        # # Set the background color to 
        # p = self.palette()
        # p.setColor(self.backgroundRole(), QColor(0x121927))
        # self.setPalette(p)

        # self.setStyleSheet("""
        #     QCodeEditor {
        #         font-family: "Courier New";
        #         font-size: 12px;
        #         color: #ffffff;
        #         background-color: #121927;
        #         border: 0px;
        #     }
        # """)

        self.textChanged.connect(self.onTextChanged)
        
        # process
        self.beginProcessThread()

    def onTextChanged(self):
        if self.focused_document != None:
            # Find the changed text
            new_text = self.toPlainText()

            # Find the changed range
            start: Position = Position(0, 0)
            end: Position = Position(0, 0)
            fc_len = len(self.focused_document.file_content)
            nt_len = len(new_text)

            # Start
            f = 0
            ns = 0
            while f < fc_len and ns < nt_len:
                if self.focused_document.file_content[f] == new_text[ns]:
                    if self.focused_document.file_content[f] == "\n":
                        start.line += 1
                        start.character = 0
                    else:
                        start.character += 1

                    f += 1
                    ns += 1
                    continue
                else:
                    break

            if f == fc_len and ns == nt_len:
                return
            
            # End
            f_eq = fc_len - 1
            ne_eq = nt_len - 1
            while f >= 0 and ne_eq >= 0:
                if self.focused_document.file_content[f_eq] != new_text[ne_eq]:
                    break
                f_eq -= 1
                ne_eq -= 1
            f_eq += 1
            ne_eq += 1
            # print(f"{f=} {self.focused_document.file_content[f]=}")

            end.line = start.line
            end.character = start.character
            ei = f
            while ei < max(f_eq, f + f_eq - ne_eq):
                if self.focused_document.file_content[ei] == "\n":
                    end.line += 1
                    end.character = 0
                else:
                    end.character += 1
                ei += 1
            # print(f"{f=}, {ns=}, {ei=}, {f_eq=}, {ne_eq=}")
        
            # Find the changed text
            changed_text: str = new_text[ns:ns + ne_eq - min(f_eq, ns)]
            # print(f"start:{start.line}:{start.character} end:{end.line}:{end.character} new:{ns}->{ne_eq}='{changed_text}'")

            self.focused_document.file_modified = True
            self.focused_document.file_modified_time = time.time()
            self.focused_document.file_saved = False
            self.focused_document.file_content = new_text
            self.focused_document.edit_version += 1

            self.sendOLSMessage(f"textDocument/didChange", {"textDocument": {"uri": f"file://{self.focused_document.file_path}",
                                                                            "version": self.focused_document.edit_version},
                                                           "contentChanges": [{"range": {"start": {"line": start.line,
                                                                                                   "character": start.character},
                                                                                         "end": {"line": end.line,
                                                                                                 "character": end.character}},
                                                                               "text": changed_text}]})

    def sendOLSMessage(self, method: str, params: dict, response_callback: callable = None):
        msg = f"{{\"jsonrpc\": \"2.0\", \"id\": {self.lsp_msg_id}, \"method\": \"{method}\", \"params\": {params}}}"
        # print("sending stdin>", msg)
        # self.com = str(f"Content-Length: {len(msg) + 0}\r\n\r\n{msg}")
        if response_callback != None:
            self.queued_ols_responses[self.lsp_msg_id] = response_callback

        self.com.put(str(f"Content-Length: {len(msg) + 0}\r\n\r\n{msg}"))
        self.lsp_msg_id += 1

    def beginProcessThread(self):
        self.com = Queue()
        print("Main    : before creating thread")
        self.process_thread = threading.Thread(target=self.processThreadFn, args=())
        self.process_thread.daemon = True
        print("Main    : before running thread")
        self.process_thread.start()

    def endProcessThread(self):
        print("ols terminating")
        self.lsp.terminate()
        print("ols terminated...")
        self.process_thread.join()
        print("process_thread rejoined")

        # self.cursorPositionChanged.connect(self.highlightCurrentLine)
        # self.highlightCurrentLine()

    def processThreadFn(self):
        input_pipe_path = "/home/rolly/proj/cass/bin/input_pipe"
        output_pipe_path = "/home/rolly/proj/cass/bin/output_pipe"
        error_pipe_path = "/home/rolly/proj/cass/bin/error_pipe"
        ols_log_path = "/home/rolly/proj/cass/bin/ols.log"

        if os.path.exists(input_pipe_path) == False:
            os.mkfifo(input_pipe_path, 0o600)
        if os.path.exists(output_pipe_path) == False:
            os.mkfifo(output_pipe_path, 0o600)
        if os.path.exists(error_pipe_path) == False:
            os.mkfifo(error_pipe_path, 0o600)

        print("pipes opening...")
        
        ip_fd = os.open("/home/rolly/proj/cass/bin/input_pipe", os.O_RDWR)
        op_fd = os.open("/home/rolly/proj/cass/bin/output_pipe", os.O_RDWR | os.O_NONBLOCK)
        ep_fd = os.open("/home/rolly/proj/cass/bin/error_pipe", os.O_RDWR | os.O_NONBLOCK)
        sout = os.fdopen(op_fd)
        serr = os.fdopen(ep_fd)
        ols_log = io.open(ols_log_path, "w+")
        print("pipes opened...")
        ols_path = "../ols/ols"
        # ols_path = "/home/rolly/.config/Code/User/globalStorage/danielgavin.ols/122834134/ols-x86_64-unknown-linux-gnu"
        self.lsp = subprocess.Popen([ols_path], stdin=ip_fd, stdout=op_fd, stderr=ep_fd, shell=False,
                                        universal_newlines=True)
        print("ols begun")
        
        while True:
            if self.lsp.poll() != None:
                # print("ols process exited")
                break
            
            # DEBUG
            # # with sin = os.fdopen(ip_fd):
            # with os.fdopen(ip_fd) as sin:
            #     outline = sin.readline()
            #     while len(outline) > 0:
            #         print("<--:", outline)
            #         # TODO process output
            #         outline = sin.readline()
            # DEBUG

            outline = sout.readline()
            while len(outline) > 0:
                # Ensure the output is a Content-Length header
                if outline.startswith("Content-Length:"):
                    ols_log.write(f"DEBUG <--{outline}")
                    ols_log.flush()

                    # Read the next line
                    content_length = int(outline.split(":")[1].strip())
                    outline = sout.readline()
                    # Ensure the output is a newline
                    if outline == "\n":
                        # Read the next line
                        outline = sout.readline(content_length)
                        # Ensure the output is a JSON message
                        if outline.startswith("{"):
                            # print("-->:", outline)
                            # outline2 = sout.readline()
                            # print("-2>:", outline2)
                            ols_log.write(f"   {outline}\r\n")
                            ols_log.flush()

                            ols_result: dict = None
                            try:
                                ols_result = decoder.JSONDecoder().decode(outline)
                            except decoder.JSONDecodeError as jde:
                                print(f"JSONDecodeError: {jde}\r\nFrom <--:`{outline}`\r\n")
                                ols_log.write(f"JSONDecodeError: {jde}\r\n")
                                ols_log.flush()

                            if ols_result != None:
                                # print("<--", ols_result)

                                if ols_result.get("id") != None:
                                    # print("here")
                                    queued_response = self.queued_ols_responses.pop(ols_result["id"], None)
                                    if queued_response != None:
                                        ols_log.write(f"DEBUG !Invoking Queued OLS Response:{queued_response}\r\n")
                                        ols_log.flush()
                                        queued_response(ols_result)
                                        # print("here2")
                                        # self.sendOLSMessage(queued_response["method"], queued_response["params"])
                                        # print("here3")
                                else:
                                    # if ols_result.get("method") == "textDocument/publishDiagnostics":\
                                    if ols_result.get("method") == "window/logMessage":
                                        if ols_result["params"]["message"] != None \
                                            and "intrinsics.odin" in ols_result["params"]["message"]:
                                            pass
                                        else:
                                            print("LSP-window/logMessage:", ols_result["params"]["message"])
                                    else:
                                        print("ERROR unhandled LSP message:", ols_result.get("method"), "\r\n", ols_result)

                            # Continue reading STDOUT
                            outline = sout.readline()
                            continue
                        else:
                            # TODO log errors
                            print("OLS-Err>expected json message")
                    else:
                        # TODO log errors
                        print("OLS-Err>expected newline that follows Content-Length header")
                else:
                    # TODO log errors
                    print("OLS-Err>expected Content-Length header, got:", outline)
                
                # Read the next
                outline = sout.readline()

            outline = serr.readline()
            while len(outline) > 0:
                ols_log.write(f"ERROR -->{msg}\r\n")
                ols_log.flush()
                print("err>", outline)
                outline = serr.readline()

            if self.com.qsize() > 0:
                # print("self.com.qsize():", self.com.qsize())
                msg = self.com.get()
                # print("-->", msg)
                # TODO log the input
                ols_log.write(f"DEBUG -->{msg}\r\n")
                ols_log.flush()
                wres = os.write(ip_fd, msg.encode())
                if wres <= 0:
                    print("STDIN write error")
                    break
                continue

            if self.focused_document != None and self.focused_document.file_modified and \
                self.focused_document.last_document_meta_info_request < self.focused_document.file_modified_time and \
                time.time() - self.focused_document.file_modified_time > 4.0:
                self.updateDocumentMetaInfo()
            
            sleep(0.05)

        # Terminate the process and close the pipes
        self.lsp.terminate()
        self.lsp = None

        sout.close()
        serr.close()
        ols_log.close()

        # os.close(ip_fd)
        # os.close(op_fd)
        # os.close(ep_fd)
        # os.close(ols_log)

        os.remove(input_pipe_path)
        os.remove(output_pipe_path)
        os.remove(error_pipe_path)
        # print("pipes removed...")

        print("process terminated & pipes closed...")

    def parseDocumentSymbol(self, ddict: dict):
        range = Range(Position(ddict["range"]["start"]["line"], ddict["range"]["start"]["character"]),
                      Position(ddict["range"]["end"]["line"], ddict["range"]["end"]["character"]))
        selection_range = Range(Position(ddict["selectionRange"]["start"]["line"], ddict["selectionRange"]["start"]["character"]),
                                Position(ddict["selectionRange"]["end"]["line"], ddict["selectionRange"]["end"]["character"]))
        symbol = DocumentSymbol(ddict["name"], ddict["kind"], range, selection_range, [])

        if ddict.get("children") != None:
            for child in ddict["children"]:
                symbol.children.append(self.parseDocumentSymbol(child))

        # print(f"Parsed Symbol: {symbol.name} {SYMBOL_KINDS[symbol.kind]} ({symbol.range.start.line}:{symbol.range.start.character} "\
        #       f" {symbol.range.end.line}:{symbol.range.end.character}) ({symbol.selectionRange.start.line}:"\
        #       f"{symbol.selectionRange.start.character} {symbol.selectionRange.end.line}:{symbol.selectionRange.end.character})"\
        #       f" {len(symbol.children)}")
        return symbol

    def processDocumentSymbols(self, response: dict):
        self.focused_document.symbols.clear()
        for symbol in response["result"]:
            self.focused_document.symbols.append(self.parseDocumentSymbol(symbol))

    def updateDocumentMetaInfo(self):
        self.focused_document.last_document_meta_info_request = time.time()

        # # Request Diagnostics
        # self.sendOLSMessage("textDocument/diagnostic", {"textDocument": {"uri": f"file://{self.focused_document.file_path}"}},
        #                     lambda response: print("diagnostic response:", response))

        # print("requesting symbols...")
        self.sendOLSMessage("textDocument/documentSymbol",
                            {"textDocument": {"uri": f"file://{self.focused_document.file_path}"}},
                            self.processDocumentSymbols)

    def openWorkspace(self, workspace: str):
        self.workspace = workspace
        self.workspace_name = workspace.split("/")[-1]
        self.workspace_uri = f"file://{workspace}"

        r = 0
        ra = 0
        while self.lsp == None:
            r += 1
            sleep(0.1)
            if r > 10:
                print("ols == None")
                return
        
        # Initialize message
        self.lsp_msg_id = 1
        self.queued_ols_responses = dict()

        def initialize_reply(response: dict):
            self.sendOLSMessage("initialized", {})

        self.sendOLSMessage("initialize", {"processId": self.lsp.pid, "capabilities": {}, "workspaceFolders":
                                       [{"uri": "file:///home/rolly/proj/cass", "name": "cass"}]}, initialize_reply)
        # self.sendOLSMessage("initialize", {"processId": self.lsp.pid, "capabilities": {},
        #                                     "workspaceFolders":[{"uri": self.workspace_uri, "name": self.workspace_name}]},
        #                          initialize_reply)
        #                                                                 # "workspace": { "inlineValue": True,
        #                                                                 #                "inlayHint": True,
        #                                                                 #                "diagnostics": True}

    def openFile(self, file_path: str):
        if file_path.endswith(".odin"):
            # Open the file
            print("Opening file", file_path)
            file = open(file_path, "r")
            file_content = file.read()
            self.setText(file_content)
            file.close()

            # Previous Focus
            if self.focused_document != None:
                RuntimeError("openFile self.focused_document != None")

            # Ensure an open-document exists for the file
            new_document = self.open_documents.get(file_path)
            if new_document == None:
                new_document = QCodeDocument()
                self.open_documents[file_path] = new_document
                new_document.file_path = file_path
                new_document.file_opened = False
                new_document.file_modified = False
                new_document.file_saved = True
                new_document.file_content = file_content
                new_document.edit_version = 1
                new_document.symbols = []
            self.focused_document = new_document
            
            # Inform the LSP that the document has been opened
            if new_document.file_opened == False:
                new_document.file_opened = True
                self.sendOLSMessage("textDocument/didOpen",
                                    {"textDocument": {"uri": f"file://{new_document.file_path}",
                                                      "languageId": "odin",
                                                      "version": 1,
                                                      "text": new_document.file_content}})
                # self.sendOLSMessage("textDocument/diagnostic", {"textDocument": {
                #                                                     "uri": f"file://{self.focused_document.file_path}"}},
                            # lambda response: print("diagnostic response:", response))
                self.sendOLSMessage("textDocument/documentSymbol",
                                    {"textDocument": {"uri": f"file://{self.focused_document.file_path}"}},
                                    self.processDocumentSymbols)
    
            return True
        if file_path.endswith(".py"):
            print("Opening file", file_path)
            file = open(file_path, "r")
            file_content = file.read()
            self.setText(file_content)
            file.close()
            return True
        return False

    def saveAllModifiedFiles(self):
        save_count = 0
        for document in self.open_documents.values():
            self.sendOLSMessage("textDocument/didSave",
                                {"textDocument": {"uri": f"file://{document.file_path}"}, "text": document.file_content})
            if document.file_modified == True:
                save_count += 1
                document.file_modified = False
                with open(document.file_path, "w") as writer:
                    writer.write(document.file_content)
                    writer.flush()
                    print("wrote to file:", document.file_path)
                document.file_saved = True
                
        print(f"saved {save_count} files")