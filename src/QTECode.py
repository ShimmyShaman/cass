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
        
        # process
        self.begin_process_thread()

    def begin_process_thread(self):
        self.com = ""
        print("Main    : before creating thread")
        x = threading.Thread(target=self.process_thread_fn, args=())
        x.daemon = True
        print("Main    : before running thread")
        x.start()
        sleep(1)
        # print("sending stdin...")
        # msg = "{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"textDocument/hover\", \"params\": {\"type\": 1, \"message\": \"int\"}}"
        msg = "{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"initialize\", \"params\": {rootUri: '/home/rolly/proj/ammo', capabilities: {}, rootPath: '/home/rolly/proj/ammo/cli/src/game_screen.odin'\"}}"
        self.com = str(f"Content-Length:{len(msg)}\r\n{msg}\r\n")
        # self.process.stdin.write(com.encode())
        # self.process.stdin.flush()
        sleep(3)
        print("ols terminating")
        self.process.terminate()
        print("ols terminated...")
        x.join()
        print("Main    : all done")

    def process_thread_fn(self):
        # if os.path.exists("input_pipe") == False:
        #     os.mkfifo("input_pipe", 448)
        # if os.path.exists("output_pipe") == False:
        #     os.mkfifo("output_pipe", 448)
        # if os.path.exists("error_pipe") == False:
        #     os.mkfifo("error_pipe", 448)

        print("ols process thread begin...")
        with io.open("input_pipe", "r+", encoding="utf-8") as input_pipe:
            print("input_pipe open...")

            # with open("output_pipe", "w") as output_pipe:
            #     with open("error_pipe", "w") as error_pipe:
            #         self.process = subprocess.Popen(["../ols/ols"], stdin=input_pipe, stdout=output_pipe, stderr=error_pipe,
            #                                         shell=False, universal_newlines=True)
                    
            #         nbsrout = NonBlockingStreamReader(self.process.stdout)
            #         print("ols begun...")
                    
            #         while True:
            #             if self.process.poll() != None:
            #                 print("ols process exited")
            #                 break
                        
            #             if len(self.com) == 0:
            #                 output = nbsrout.readline(0.5)
            #                 if output != None:
            #                     print('LS-UnOut:', output)
            #                     continue
            #                 sleep(1)
            #                 continue
                        
            #             print("sending stdin:", self.com)
            #             self.process.stdin.write(self.com)
            #             self.process.stdin.flush()
            #             self.com = ""


        # while proc.returncode is None:
        #     proc.poll()
        # self.process = subprocess.Popen(["../ols/ols"], stdin=pin, stdout=pout, stderr=perr, shell=False, universal_newlines=True)


        # nbsrout = NonBlockingStreamReader(self.process.stdout)
        # nbsrerr = NonBlockingStreamReader(self.process.stderr)

        # # get the output
        # print("ols begun...")
        # while True:
        #     if self.process.poll() != None:
        #         print("ols process exited")
        #         break
            
        #     if len(self.com) == 0:
        #     #     output = nbsrout.readline(0.5)
        #     #     if output != None:
        #     #         print('LS-UnOut:', output)
        #     #         continue
        #     #     output = nbsrerr.readline(0.2)
        #     #     if output != None:
        #     #         print('LS-UnErr:', output)
        #     #         continue
        #     #     print("ols stdout empty")
        #         sleep(1)
        #         continue
            
        #     print("sending stdin:", self.com)
        #     self.process.stdin.write(self.com)
        #     self.process.stdin.flush()

        #     # reader = io.TextIOWrapper(self.process.stdout, encoding='utf8')
        #     # char = reader.read(1)
        #     # print("ols stdout:", char)
        #     # soo, seo = self.process.communicate(input=self.com, timeout=1.3)
        #     # print("ols stdout:", soo)
        #     # print("ols stderr:", seo)

        #     self.com = ""

        #     # while True:
        #     #     output = nbsr.readline(0.4)
        #     #     if output == None:
        #     #         print('LS-Out END')
        #     #         break
        #     #     print('LS-Out:', output)
        
        # print("loop exited")

        # # self.process.wait()
        # while True:
        # #     # sleep(1.2)
        # #     # print("readable=",self.process.stdout.readable())
        # #     line = self.process.stdout.readline()
        # #     print("ols OUT:", self.process.stdout.read())
        # #     if not line:
        # #         break
        # # print("ols terminating")
        # # self.process.terminate()
        # print("ols process thread end.")

        # self.cursorPositionChanged.connect(self.highlightCurrentLine)
        # self.highlightCurrentLine()

    def openFile(self, file_path: str):
        if file_path.endswith(".odin"):
            print("Opening file", file_path)
            file = open(file_path, "r")
            file_content = file.read()
            self.setText(file_content)
            file.close()
            return True
        if file_path.endswith(".py"):
            print("Opening file", file_path)
            file = open(file_path, "r")
            file_content = file.read()
            self.setText(file_content)
            file.close()
            return True
        return False