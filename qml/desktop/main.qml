import QtQuick 2.2
import QtQuick.Window 2.1
import QtQuick.Controls 1.2
import Calaos 1.0
import SharedComponents 1.0
import QuickFlux 1.0
import "../quickflux"
import QtQuick.VirtualKeyboard.Settings 2.2

Window {
    id: rootWindow
    visible: true

    width: Units.dp(1024) * calaosApp.density
    height: Units.dp(768) * calaosApp.density

    property QtObject roomModel
    property string currentRoomName
    property string currentRoomType
    property QtObject cameraSingleModel

    property bool isSingleCameraView: false

    //this is called by HardwareUtils
    function showAlertMessage(title, message, buttonText) {
        notif.showMessage(title, message)
    }

    //this is called by HardwareUtils
    function showNetworkActivity(en) {
        //TODO
    }

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

    function handleSubitemClick(itemId) {
        var item;
        if (itemId == "media/music") {
            item = musicListView
        }
        else if (itemId == "media/camera") {
            item = cameraListView
        } else if (itemId == "media/web") {
            item = webView
        } else if (itemId == "config/screen") {
            item = configScreen
        } else if (itemId == "config/l18n") {
            item = configL18nView
        } else if (itemId == "config/info") {
            item = configUserInfoView
        } else if (itemId == "media/spotify") {
            item = spotifyView
        }else if (itemId == "media/deezer") {
            item = deezerView
        }

        stackView.push(item)
    }

    function openColorPicker(item, cb) {
        dialogRgbColorPicker.openWithIO(item, cb)
    }

    //Load fonts
    Fonts { id: calaosFont }

    Background {
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

            delegate: StackViewAnim {}

            // Implements back key navigation
            focus: true
            Keys.onReleased: if (event.key === Qt.Key_Back || event.key === Qt.Key_Backspace) {
                                 handleBack()
                                 event.accepted = true;
                             }

            onCurrentItemChanged: {
                if ('hideMainMenu' in currentItem) {
                    if (currentItem.hideMainMenu)
                        AppActions.hideMainMenu()
                    else
                        AppActions.showMainMenu()
                } else
                    AppActions.showMainMenu()
            }
        }
    }

    Component.onCompleted: {
        Units.cachedValue = Qt.binding(function() {
            return calaosApp.density;
        });

        VirtualKeyboardSettings.styleName = "calaos"
    }

    Component {
        id: desktopView

        DesktopView {
        }
    }

    Component {
        id: homeView

        HomeView {
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

        RoomDetailView {
            height: parent.height
            width: parent.width

            roomItemModel: roomModel
        }
    }

    Component {
        id: cameraSingleView

        CameraSingleView {
            height: parent.height
            width: parent.width

            camModel: cameraSingleModel
        }
    }

    Component {
        id: mediaMenuView
        MediaView {}
    }

    Component {
        id: scenariosView
        ScenarioView {}
    }

    Component {
        id: configPanelView
        ConfigView {}
    }

    Component {
        id: musicListView
        MusicListView {}
    }

    Component {
        id: cameraListView
        CameraListView {}
    }

    Item {
        //Webview are not deleted when popped from StackView.
        //It allows user to keep the current website open to it's last page
        id: webParent
        visible: false

        Loader {
            id: webView
            property bool hideMainMenu: true
            source: "qrc:/qml/desktop/MediaWebView.qml"
        }
        Loader {
            id: spotifyView
            property bool hideMainMenu: true
            source: "qrc:/qml/desktop/SpotifyView.qml"
        }
        Loader {
            id: deezerView
            property bool hideMainMenu: true
            source: "qrc:/qml/desktop/DeezerView.qml"
        }
    }

    Component {
        id: configScreen
        ConfigScreenView {}
    }

    Component {
        id: configL18nView
        ConfigL18nView {}
    }

    Component {
        id: configUserInfoView
        ConfigUserInfoView {}
    }

    Notification {
        id: notif
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
    }

    //This overlay is for displaying dialogs on top of everything
    OverlayLayer {
        id: dialogOverlayLayer
        objectName: "dialogOverlayLayer"
    }

    DialogReboot { id: dialogReboot }

    DialogRGBColorPicker { id: dialogRgbColorPicker }

    DialogKeyboard { id: dialogKeyboard }

    //Dispatch actions
    AppListener {
        Filter {
            type: ActionTypes.clickHomeboardItem
            onDispatched: {
                if (message.text == "reboot") {
                    dialogReboot.show()
                } else if (message.text == "screensaver") {
                    AppActions.suspendScreen()
                }
            }
        }
        Filter {
            type: ActionTypes.openCameraSingleView
            onDispatched: {
                cameraSingleModel = message.camModel
                stackView.push(cameraSingleView)
            }
        }
        Filter {
            type: ActionTypes.openAskTextForIo

            property QtObject io

            onDispatched: {
                io = message.io
                console.log("todo keyboard for item:" + io + " - " + io.ioName)
                dialogKeyboard.openKeyboard(qsTr("Keyboard"),
                                            qsTr("Change text for '%1'").arg(io.ioName),
                                            io.stateString,
                                            false,
                                            function (txt) {
                                                io.sendStringValue(txt)
                                            })
            }
        }
        Filter {
            type: ActionTypes.openKeyboard

            onDispatched: {
                dialogKeyboard.openKeyboard(message.title,
                                            message.subtitle,
                                            message.initialText,
                                            message.multiline,
                                            function (txt) {
                                                AppDispatcher.dispatch(message.returnAction,
                                                                       { text: txt,
                                                                         returnPayload: message.returnPayload })
                                            })
            }
        }
    }

    //This should stay at the top of all object layer
    ScreenSuspend {
        id: screenSuspend
    }

    Connections {
        target: cameraModel
        onActionViewCamera: AppActions.openCameraSingleView(camModel)
    }
}
