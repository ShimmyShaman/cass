import sys
from PyQt5.QtCore import *
from PyQt5.QtGui import *
from PyQt5.QtWidgets import *

def window():
   app = QApplication(sys.argv)

   win = QWidget()
   win.setGeometry(240,180,1400,640)
   win.setWindowTitle("cass")

   b = QLabel(win)
   b.setText("Hello World!")
   b.move(240,180)
   
   win.show()
   sys.exit(app.exec_())
if __name__ == "__main__":
   window()