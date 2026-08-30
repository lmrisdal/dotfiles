import QtQuick

Row {
    id: root

    required property var itemNames
    required property var barContext

    height: 40
    spacing: 0

    Repeater {
        model: root.itemNames

        delegate: Loader {
            id: itemLoader

            required property string modelData
            property var registeredItem: null

            height: root.height
            sourceComponent: root.barContext.componentFor(modelData)

            onLoaded: {
                registeredItem = item
                root.barContext.registerItem(modelData, item)
            }

            onItemChanged: {
                if (!item && registeredItem) {
                    root.barContext.unregisterItem(modelData, registeredItem)
                    registeredItem = null
                }
            }

            Component.onDestruction: {
                if (registeredItem)
                    root.barContext.unregisterItem(modelData, registeredItem)
            }
        }
    }
}
