import Quickshell
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: root

    readonly property var activeTask: tasksModel.activeTask
    readonly property string applicationName: activeTask.valid
        ? tasksModel.data(activeTask, TaskManager.AbstractTasksModel.AppName) || ""
        : ""

    visible: applicationName !== ""
    implicitWidth: visible ? Math.min(applicationLabel.implicitWidth + 16, 256) : 0
    implicitHeight: applicationLabel.implicitHeight

    TaskManager.TasksModel {
        id: tasksModel

        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    Text {
        id: applicationLabel

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.applicationName
        color: "#cdd6f4"
        font.pixelSize: 14
        font.bold: true
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
