import sys
from PyQt5.QtCore import *
from PyQt5.QtGui import *
from PyQt5.QtWidgets import *

class MyWindow(QWidget):
   def __init__(self):
      super().__init__()
      self.setGeometry(240,180,1400,640)
      self.setWindowTitle("cass")
      self.setWindowFlag(Qt.FramelessWindowHint)

      # Set the background color to 
      p = self.palette()
      p.setColor(self.backgroundRole(), QColor(0x121927))
      self.setPalette(p)

      # Win View
      win_view = QVBoxLayout()
      win_view.setContentsMargins(0,0,0,0)
      grab_bar = QLabel()
      grab_bar.setFixedHeight(18)
      grab_bar.setStyleSheet("background-color: #1e2a5a;")
      app_view = QHBoxLayout()
      win_view.addWidget(grab_bar)
      win_view.addLayout(app_view)

      # App View
      app_view.setSpacing(4)
      project_view = QVBoxLayout()
      project_view.setSpacing(2)
      working_view = QGridLayout()
      app_view.addLayout(project_view)
      app_view.addLayout(working_view)

      label = QLabel()
      label.setText("Working View")
      label.setStyleSheet("background-color: #121724; font-size: 24px; color: #fafafa;")
      label.setAlignment(Qt.AlignCenter)
      label.setMinimumSize(1000, 600)
      label.setAutoFillBackground(True)
      working_view.addWidget(label)

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
      
      self.tree.setMaximumWidth(320)
      self.tree.setAnimated(False)
      self.tree.setIndentation(20)
      self.tree.setSortingEnabled(True)
      self.tree.setColumnHidden(1, True)
      self.tree.setColumnHidden(2, True)
      self.tree.setColumnHidden(3, True)
      self.tree.setGeometry(QRect(4, 40, 640, 160))

      self.tree.doubleClicked.connect(treeDoubleClick)
      
      self.tree.setWindowTitle("Dir View")
      self.tree.resize(640, 480)
      project_view.addWidget(self.tree)
      # Set the layout to the left hand side of the window
      # windowLayout.setGeometry(QRect(4, 40, 640, 160))
      # windowLayout.setSizeConstraint(QLayout.SetDefaultConstraint)
      self.setLayout(win_view)

   def keyPressEvent(self, event):
      #  if key is f4 or escape
       if event.key() == Qt.Key_F4 or event.key() == Qt.Key_Escape:
           self.close()

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

def treeDoubleClick(index):
   print("treeDoubleClick", index)
   file_path = win.file_system_model.filePath(index)
   print(file_path)

# Global variables
app = QApplication(sys.argv)
win: MyWindow = MyWindow()
project: WorkingProject = None

# Debug
# openProject("/home/rolly/proj/cass0")
openProject("/home/rolly/proj/ammo")

# Entry Point
if __name__ == "__main__":

   win.show()
   sys.exit(app.exec_())