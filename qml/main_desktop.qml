import QtQuick 2.2
import QtQuick.Window 2.1
import QtQuick.Controls 1.2
import Calaos 1.0
import "calaos.js" as Calaos;
import Units 1.0

Window {
    id: rootWindow
    visible: true

    width: Units.dp(1024) * calaosApp.density
    height: Units.dp(768) * calaosApp.density

    property variant roomModel
    property string currentRoomName
    property string currentRoomType

    property bool isSingleCameraView: false

    function goToDesktop() {
        mainMenu.unselectAll()
        stackView.pop({ item: desktopView })
    }

    function handleBack() {
        //enable all cameras if going back to CameraListView
        if (isSingleCameraView) {
            cameraModel.cameraVisible = true
            isSingleCameraView = false
        }
        else
            cameraModel.cameraVisible = false

        if (stackView.depth > 1) {
            stackView.pop()
            if (stackView.depth == 1)
                mainMenu.unselectAll()
        }
    }

    function handleMediaClick(itemId) {
        var item;
        if (itemId == "music") {
            item = musicListView
        }
        else if (itemId == "camera") {
            item = cameraListView
        } else if (itemId == "web") {
            item = webView
        }

        stackView.push(item)
    }

    //Load fonts
    Fonts { id: calaosFont }

    BackgroundDesktop {
        anchors.fill: parent

        menuContent: MainMenu {
            id: mainMenu

            onButtonHomeClicked: {                
                if (currentButton == 0)
                    stackView.push(homeView)
                else
                    stackView.replace(homeView)
            }
            onButtonMediaClicked: {
                if (currentButton == 0)
                    stackView.push(mediaMenuView)
                else
                    stackView.replace(mediaMenuView)
            }
            onButtonScenariosClicked: {
                if (currentButton == 0)
                    stackView.push(scenariosView)
                else
                    stackView.replace(scenariosView)
            }
            onButtonConfigClicked: {
                if (currentButton == 0)
                    stackView.push(configPanelView)
                else
                    stackView.replace(configPanelView)
            }
        }

        mainContent: StackView {
            id: stackView
            anchors.fill: parent

            initialItem: desktopView

            delegate: DesktopStackViewAnim {}

            // Implements back key navigation
            focus: true
            Keys.onReleased: if (event.key === Qt.Key_Back || event.key === Qt.Key_Backspace) {
                                 handleBack()
                                 event.accepted = true;
                             }
        }
    }

    Component.onCompleted: {
        Units.cachedValue = Qt.binding(function() {
            return calaosApp.density;
        });
    }

    Component {
        id: desktopView

        DesktopView {
        }
    }

    Component {
        id: homeView

        DesktopHomeView {
            model: homeModel

            onRoomClicked: {
                //get room model
                console.debug("model: " + homeModel)
                roomModel = homeModel.getRoomModel(idx)
                currentRoomName = room_name
                currentRoomType = room_type
                stackView.push(roomDetailView)
            }
        }
    }

    Component {
        id: roomDetailView

        DesktopRoomDetailView {
            height: parent.height
            width: parent.width

            roomItemModel: roomModel
        }
    }

    Component {
        id: mediaMenuView
        DesktopMediaView {}
    }

    Component {
        id: scenariosView
        DesktopScenarioView {}
    }

    Component {
        id: configPanelView
        DesktopConfigView {}
    }

    Component {
        id: musicListView
        DesktopMusicListView {}
    }

    Component {
        id: cameraListView
        DesktopCameraListView {}
    }

    Component {
        id: webView
        DesktopWebView {}
    }
}