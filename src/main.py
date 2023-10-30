import sys
from PyQt5.QtCore import *
from PyQt5.QtGui import *
from PyQt5.QtWidgets import *
from QTECode import QCodeEditor

class MyWindow(QWidget):
   def __init__(self):
      super().__init__()
      self.setGeometry(140,180,1700,740)
      self.setWindowTitle("cass")
      self.setWindowFlag(Qt.FramelessWindowHint)

      # Set the background color to 
      p = self.palette()
      p.setColor(self.backgroundRole(), QColor(0x121927))
      self.setPalette(p)

      shortcut = QShortcut(QKeySequence("Ctrl+S"), self)
      shortcut.activated.connect(self.saveAll)

      # Win View
      win_view = QVBoxLayout()
      win_view.setContentsMargins(0,0,0,0)
      
      grab_bar = QLabel()
      grab_bar.setFixedHeight(18)
      grab_bar.setStyleSheet("background-color: #1e2a5a;")
      win_view.addWidget(grab_bar)

      # App View
      self.app_view = QGridLayout()
      self.app_view.setContentsMargins(0,0,0,0)
      self.app_view.setSpacing(0)
      self.app_view.setColumnStretch(0, 1)
      self.app_view.setColumnStretch(1, 4)
      # self.app_view.setColumnStretch(2, 5)
      win_view.addLayout(self.app_view)

      # Project View
      self.init_project_view(self.app_view)

      # # AI View
      # self.init_ai_view(app_view)

      # Working View
      self.init_working_view(self.app_view)

      self.setLayout(win_view)

   def init_project_view(self, app_view):
      project_view = QVBoxLayout()
      project_view.setSpacing(2)
      app_view.addLayout(project_view, 0, 0)

      self.project_button = QPushButton(self)
      self.project_button.setText("Open Project...")
      self.project_button.move(20,20)
      self.project_button.clicked.connect(openProjectButtonDialogResult)
      self.project_button.setMaximumWidth(320)
      project_view.addWidget(self.project_button)

      self.file_system_model = QFileSystemModel()
      self.file_system_model.setRootPath('')
      self.tree = QTreeView()
      self.tree.setModel(self.file_system_model)
   
      # self.tree.setMaximumWidth(320)
      # self.tree.setMinimumWidth(320)
      self.tree.setFixedWidth(320)
      self.tree.setAnimated(False)
      self.tree.setIndentation(20)
      self.tree.setSortingEnabled(True)
      self.tree.setColumnHidden(1, True)
      self.tree.setColumnHidden(2, True)
      self.tree.setColumnHidden(3, True)
      self.tree.setGeometry(QRect(4, 40, 640, 160))

      self.tree.clicked.connect(self.treeDoubleClick)
   
      self.tree.setWindowTitle("Dir View")
      self.tree.resize(640, 480)
      project_view.addWidget(self.tree)

   def treeDoubleClick(self, index):
      # print("treeDoubleClick", index)
      file_path = win.file_system_model.filePath(index)

      if win.file_system_model.isDir(index) == False:
         if win.code_editor.openFile(file_path) == False:
            print("Unrecognised file type, cannot open:", file_path)

   def init_ai_view(self, app_view):
      ai_view = QStackedLayout()
      # ai_view.setSizeConstraint(QLayout.SizeConstraint.SetFixedSize)
      app_view.addLayout(ai_view, 0, 1)

      chat_scroll = QScrollArea()
      chat_scroll.setFixedWidth(380)
      chat_scroll.horizontalScrollBar().hide()
      ai_view.addWidget(chat_scroll)
      
      # Create and add 5 labels to the scroll area
      chat_scroll_content = QWidget()
      # chat_scroll_content.setFixedWidth(320)
      chat_scroll_content.setLayout(QVBoxLayout())
      chat_scroll_content.layout().setAlignment(Qt.AlignBottom)

      # chat_scroll.setMaximumWidth(320)
      chat_scroll.setWidget(chat_scroll_content)
      chat_scroll.setWidgetResizable(True)

      for i in range(9):
         label = QLabel()
         label.setText("Chat " + str(i) + "\nAnother series of words of big\n bang and hokus pokus\n and other stuff.")
         label.setStyleSheet("background-color: #82A794; font-size: 17px; color: #1a1a1a;")
         label.setAlignment(Qt.AlignCenter)
         label.setWordWrap(True)
      # label.setMinimumSize(1000, 600)
         label.setAutoFillBackground(True)
         chat_scroll_content.layout().addWidget(label)

   def init_working_view(self, app_view):
      working_view = QGridLayout()
      working_view.setContentsMargins(0, 0, 0, 12)
      app_view.addLayout(working_view, 0, 1)

      # Set the background color of the QGridLayout
      self.code_editor = QCodeEditor()

      working_view.addWidget(self.code_editor, 0, 0)

   def keyPressEvent(self, event):
      #  if key is f4 or escape
      if event.key() == Qt.Key_F4 or event.key() == Qt.Key_Escape:
         self.code_editor.endProcessThread()
         self.close()

   def saveAll(self):
      print("Saving all files...")

class WorkingProject():
   def __init__(self, root_dir) -> None:
      self.root_dir = root_dir

def openProjectButtonDialogResult():
   options = QFileDialog.Options()
   options |= QFileDialog.DontUseNativeDialog
   options |= QFileDialog.ShowDirsOnly
   folder_path = QFileDialog.getExistingDirectory(win, "Open project_button Directory", "", options=options)
   
   openProject(folder_path)

# Opens the project at the specified folder_path
def openProject(folder_path):
   print("Opening project...", folder_path)
   project = WorkingProject(folder_path)

   win.file_system_model.setRootPath(folder_path)
   win.tree.setRootIndex(win.file_system_model.index(folder_path))

   # Disable the open project_button button
   win.project_button.setEnabled(False)

   # Get the last folder name from the path
   folder_name = folder_path.split("/")[-1]
   win.project_button.setText(folder_name)

# Global variables
app = QApplication(sys.argv)
win: MyWindow = MyWindow()
project: WorkingProject = None

# Debug
# openProject("/home/rolly/proj/cass")
openProject("/home/rolly/proj/ammo")

# Entry Point
if __name__ == "__main__":

   win.show()
   sys.exit(app.exec_())