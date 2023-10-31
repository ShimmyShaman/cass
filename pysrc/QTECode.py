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

class QCodeDocument:
    def __init__(self):
        self.file_path = ""
        self.file_content = ""
        self.file_modified = False
        self.file_opened = False
        self.file_saved = False

class QCodeEditor(QTextEdit):
    def __init__(self):
        super().__init__()
        # self.setSizeAdjustPolicy(QAbstractScrollArea.AdjustIgnored)
        self.setStyleSheet("background-color: #161618; color: #F8F8FF;")
        # self.setTabStopWidth(20)
        # self.setTabChangesFocus(True)
        # self.setAcceptRichText(False)
        self.setLineWrapMode(QTextEdit.NoWrap)
        # self.setAcceptDrops(False)
        # self.setUndoRedoEnabled(True)
        # self.setOverwriteMode(False)
        # self.setReadOnly(False)
        # self.setLineWrapColumnOrWidth(0)
        # self.setPlaceholderText("Code Editor")
        self.setFrameShape(QFrame.StyledPanel)
        self.setFrameShadow(QFrame.Plain)

        # Stretch the code editor to fill the working view
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        # self.setAcceptRichText(False)
        # self.setTabStopWidth(20)
        # self.setLineWrapMode(QTextEdit.NoWrap)
        # self.setWordWrapMode(QTextOption.NoWrap)
        # self.setUndoRedoEnabled(True)
        # self.setAcceptDrops(True)

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
        self.openDocuments = dict()
        
        # process
        self.beginProcessThread()

    def onTextChanged(self):
        print("onTextChanged")
        if self.focusedDocument != None:
            self.focusedDocument.file_modified = True
            self.focusedDocument.file_saved = False

    def beginProcessThread(self):
        self.com = Queue()
        print("Main    : before creating thread")
        self.process_thread = threading.Thread(target=self.processThreadFn, args=())
        self.process_thread.daemon = True
        print("Main    : before running thread")
        self.process_thread.start()
        sleep(1)
        
        # Initialize message
        self.lsp_msg_id = 1
        self.queued_ols_responses = dict()

        def initialize_reply(response: dict):
            self.sendOLSMessage("initialized", {})
        self.sendOLSMessage("initialize", {"processId": self.ols.pid, "capabilities": {}, "workspaceFolders":
                                       [{"uri": "file:///home/rolly/proj/ammo", "name": "ammo"}]}, initialize_reply)

    def sendOLSMessage(self, method: str, params: dict, response_callback: callable = None):
        msg = f"{{\"jsonrpc\": \"2.0\", \"id\": {self.lsp_msg_id}, \"method\": \"{method}\", \"params\": {params}}}"
        # print("sending stdin>", msg)
        # self.com = str(f"Content-Length: {len(msg) + 0}\r\n\r\n{msg}")
        if response_callback != None:
            self.queued_ols_responses[self.lsp_msg_id] = response_callback

        self.com.put(str(f"Content-Length: {len(msg) + 0}\r\n\r\n{msg}"))
        self.lsp_msg_id += 1

    # def queueOLSMessageResponse(self, msg_id: int, method: str, params: dict):
    #     self.queued_ols_responses[msg_id] = {"method": method, "params": params}
    
    # def queueOLSCallbackResponse(self, msg_id: int, )

    def endProcessThread(self):
        print("ols terminating")
        self.ols.terminate()
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
        # ols_path = "../ols/ols"
        ols_path = "/home/rolly/.config/Code/User/globalStorage/danielgavin.ols/122834134/ols-x86_64-unknown-linux-gnu"
        self.ols = subprocess.Popen([ols_path], stdin=ip_fd, stdout=op_fd, stderr=ep_fd, shell=False,
                                        universal_newlines=True)
        print("ols begun")
        
        while True:
            if self.ols.poll() != None:
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
                ols_log.write(f"<--{outline}\r\n")
                ols_log.flush()
                # print("-->:", outline, end="")

                # Ensure the output is a Content-Length header
                if outline.startswith("Content-Length:"):
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
                            ols_log.write(f"<--{outline}\r\n")
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
                                        ols_log.write(f"!Invoking Queued OLS Response:{queued_response}\r\n")
                                        ols_log.flush()
                                        queued_response(ols_result)
                                        # print("here2")
                                        # self.sendOLSMessage(queued_response["method"], queued_response["params"])
                                        # print("here3")

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
                # TODO log errors
                print("err>", outline)
                # TODO process errors
                outline = serr.readline()

            if self.com.qsize() > 0:
                # print("self.com.qsize():", self.com.qsize())
                msg = self.com.get()
                # print("-->", msg)
                # TODO log the input
                ols_log.write(f"-->{msg}\r\n")
                ols_log.flush()
                wres = os.write(ip_fd, msg.encode())
                if wres <= 0:
                    print("STDIN write error")
                    break
                continue
            
            sleep(0.05)

        # Terminate the process and close the pipes
        self.ols.terminate()

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

    def processDocumentSymbols(self, response: dict):
        print("processDocumentSymbols:", response)

    def openFile(self, file_path: str):
        if file_path.endswith(".odin"):
            # Open the file
            print("Opening file", file_path)
            file = open(file_path, "r")
            file_content = file.read()
            self.setText(file_content)
            file.close()

            # Ensure an open-document exists for the file
            new_document = self.openDocuments.get(file_path)
            if new_document == None:
                new_document = QCodeDocument()
                self.openDocuments[file_path] = new_document
                new_document.file_path = file_path
                new_document.file_opened = False
                new_document.file_modified = False
                new_document.file_saved = True
                new_document.file_content = file_content
            self.focusedDocument = new_document
            
            # Inform the LSP that the document has been opened
            if new_document.file_opened == False:
                new_document.file_opened = True
                self.sendOLSMessage("textDocument/didOpen",
                                    {"textDocument": {"uri": f"file://{new_document.file_path}",
                                                      "languageId": "odin",
                                                      "version": 1,
                                                      "text": new_document.file_content}})
                self.sendOLSMessage("textDocument/documentSymbol",
                                    {"textDocument": {"uri": f"file://{self.focusedDocument.file_path}"}},
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
        for document in self.openDocuments.values():
            if document.file_modified == True:
                document.file_modified = False
                with open(document.file_path, "w") as writer:
                    writer.write(document.file_content)
                document.file_saved = True
                self.sendOLSMessage("textDocument/didSave",
                                    {"textDocument": {"uri": f"file://{document.file_path}"}})