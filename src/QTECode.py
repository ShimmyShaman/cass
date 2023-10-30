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

class NonBlockingStreamReader:
    def __init__(self, stream):
        '''
        stream: the stream to read from.
                Usually a process' stdout or stderr.
        '''

        self._s = stream
        self._q = Queue()

        def _populateQueue(stream, queue):
            '''
            Collect lines from 'stream' and put them in 'quque'.
            '''

            while True:
                line = stream.readline()
                if line:
                    queue.put(line)
                else:
                    raise UnexpectedEndOfStream

        self._t = Thread(target = _populateQueue,
                args = (self._s, self._q))
        self._t.daemon = True
        self._t.start() #start collecting lines from the stream

    def readline(self, timeout = None):
        try:
            return self._q.get(block = timeout is not None,
                    timeout = timeout)
        except Empty:
            return None

class UnexpectedEndOfStream(Exception):
    pass

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

        self.openDocuments = dict()
        
        # process
        self.beginProcessThread()

    def beginProcessThread(self):
        self.com = ""
        print("Main    : before creating thread")
        self.process_thread = threading.Thread(target=self.processThreadFn, args=())
        self.process_thread.daemon = True
        print("Main    : before running thread")
        self.process_thread.start()
        sleep(1)
        
        # Initialize message
        # init_msg = f"{{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"initialize\", \"params\": {{\"processId\": {self.process.pid}, "\
        #             f"\"capabilities\": {{}}, \"workspaceFolders\": [{{\"uri\": \"file:///home/rolly/proj/ammo\", \"name\": \"ammo\"}}]}}}}"
        # self.com = str(f"Content-Length: {len(init_msg) + 0}\r\n\r\n{init_msg}")
        self.lsp_msg_id = 1
        self.queued_ols_responses = dict()
        self.queueOLSMessageResponse(self.lsp_msg_id, "initialized", {})
        self.sendOLSMessage("initialize", {"processId": self.ols.pid, "capabilities": {}, "workspaceFolders":
                                       [{"uri": "file:///home/rolly/proj/ammo", "name": "ammo"}]})

        # print("sending stdin...")
        # msg = "{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"textDocument/hover\", \"params\": {\"type\": 1, \"message\": \"int\"}}"
        # msg = "{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"initialize\", \"params\": {rootUri: '/home/rolly/proj/ammo', capabilities: {}, rootPath: '/home/rolly/proj/ammo/cli/src/game_screen.odin'\"}}"
        # self.com = str(f"Content-Length:{len(msg) + 0}\r\n\r\n{msg}")
        # sleep(3)
        # # print("TODO process.terminate")
        # self.process.terminate()
        # print("ols terminated...")
        # x.join()
        # print("Main    : all done")

    def sendOLSMessage(self, method: str, params: dict):
        msg = f"{{\"jsonrpc\": \"2.0\", \"id\": {self.lsp_msg_id}, \"method\": \"{method}\", \"params\": {params}}}"
        # print("sending stdin>", msg)
        self.com = str(f"Content-Length: {len(msg) + 0}\r\n\r\n{msg}")
        self.lsp_msg_id += 1

    def queueOLSMessageResponse(self, msg_id: int, method: str, params: dict):
        self.queued_ols_responses[msg_id] = {"method": method, "params": params}

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
                # TODO log output
                print("-->:", outline, end="")

                # Ensure the output is a Content-Length header
                if outline.startswith("Content-Length:"):
                    # Read the next line
                    outline = sout.readline()
                    # Ensure the output is a newline
                    if outline == "\n":
                        # Read the next line
                        outline = sout.readline()
                        # Ensure the output is a JSON message
                        if outline.startswith("{"):
                            # print("-->:", outline)
                            print("here3")
                            sleep(1.1)
                            # outline2 = sout.readline()
                            # print("-2>:", outline2)
                            ols_result = decoder.JSONDecoder().decode(outline)
                            print("-->", ols_result)

                            if ols_result.get("id") != None:
                                queued_response = self.queued_ols_responses.pop(ols_result["id"], None)
                                if queued_response != None:
                                    self.sendOLSMessage(queued_response["method"], queued_response["params"])

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

            if len(self.com) == 0:
                sleep(0.1)
                continue
            
            # TODO log the input
            wres = os.write(ip_fd, self.com.encode())
            if wres <= 0:
                break
            self.com = ""

        # Terminate the process and close the pipes
        self.ols.terminate()
        os.close(ip_fd)
        os.close(op_fd)
        os.close(ep_fd)

        os.remove(input_pipe_path)
        os.remove(output_pipe_path)
        os.remove(error_pipe_path)
        # print("pipes removed...")

        print("process terminated & pipes closed...")

    # class JsonMsg:
    #     self.jsonRpcVersion = ""
    #     self.id = 0
    #     self.result = dict()


    # def parseJsonMessage(self, json_msg: str):
    #     print("jm[id]=", jm["id"])
    #     print("jm[result]=", jm["result"])


    def openFile(self, file_path: str):
        if file_path.endswith(".odin"):
            print("Opening file", file_path)
            file = open(file_path, "r")
            file_content = file.read()
            self.setText(file_content)
            file.close()

            new_document = self.openDocuments.get(file_path)
            if new_document == None:
                new_document = QCodeDocument()
                self.openDocuments[file_path] = new_document
                new_document.file_path = file_path
                new_document.file_opened = False
                new_document.file_modified = False
                new_document.file_saved = True
                new_document.file_content = file_content
            
            if new_document.file_opened == False:
                new_document.file_opened = True
                self.sendOLSMessage("textDocument/didOpen", {"textDocument": {"uri": f"file://{new_document.file_path}",
                                                                              "languageId": "odin",
                                                                              "version": 1,
                                                                              "text": new_document.file_content}})
            return True
        if file_path.endswith(".py"):
            print("Opening file", file_path)
            file = open(file_path, "r")
            file_content = file.read()
            self.setText(file_content)
            file.close()
            return True
        return False