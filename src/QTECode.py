import sys
import subprocess
import threading
from time import sleep
import time

from PyQt5.QtCore import *
from PyQt5.QtGui import *
from PyQt5.QtWidgets import *

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
        print("Main    : before creating thread")
        x = threading.Thread(target=self.process_thread_fn, args=())
        print("Main    : before running thread")
        x.start()
        sleep(1)
        print("sending stdin...")
        # msg = "{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"textDocument/hover\", \"params\": {\"type\": 1, \"message\": \"int\"}}"
        msg = "{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"initialize\", \"params\": {rootUri: 'file:///Users/prabirshrestha/tmp/helloworld', capabilities: \{\}, rootPath: 'file:///Users/prabirshrestha/tmp/helloworld'\"}}"
        com = str(f"Content-Length:{len(msg)}\r\n{msg}\r\n")
        fmt.println("sending stdin: " + com)
        self.process.stdin.write(com.encode())
        self.process.stdin.flush()
        sleep(4)
        print("ols terminating")
        self.process.terminate()
        print("ols terminated...")
        x.join()
        print("Main    : all done")

    def process_thread_fn(self):
        self.process = subprocess.Popen(["../ols/ols"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print("ols begun...")
        # self.process.wait()
        time_now = time.time()
        for line in self.process.stdout:
            print("ols OUT:", line)
        # print("ols terminating")
        # self.process.terminate()
        # print("ols terminated...")

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