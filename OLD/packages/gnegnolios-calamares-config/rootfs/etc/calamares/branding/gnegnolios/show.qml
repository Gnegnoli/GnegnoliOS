import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0D0D0D"
        }
        Image {
            anchors.centerIn: parent
            width: parent.width * 0.35
            fillMode: Image.PreserveAspectFit
            source: "gnegnolios-mark.png"
        }
    }

    Slide {
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: "file:///usr/share/wallpapers/GnegnoliOSGenesis/contents/images/1536x1024.png"
        }
    }

    function activate() {
        presentation.currentSlide = 0
    }
    function deactivate() { }
}
