import sys
from PyQt5.QtCore import *
from PyQt5.QtGui import *
from PyQt5.QtWidgets import *

def window():
   app = QApplication(sys.argv)
   w = QWidget()
   b = QLabel(w)
   w.setGeometry(300,200,1100,540)
   w.setWindowTitle("PyQt5")
   b.setText("Hello World!")
   b.move(500,200)
   w.show()
   sys.exit(app.exec_())
if __name__ == '__main__':
   window()