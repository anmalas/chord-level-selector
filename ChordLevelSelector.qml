//==========================================================================================
//  Chord Level Select for MuseScore
//  Has been tested in custom 3.7 branch, 3.6.2,
//  and to be tested on 4.x

//  Errors or suggestions or whatever @ https://musescore.org/en/node/328754
//  Maybe I should get a git branch for this thing...
//
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 2
//  as published by the Free Software Foundation and appearing in
//  the file LICENCE.GPL
//===========================================================================================
import QtQuick 2.1
import QtQuick.Controls 1.0
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs 1.1
import MuseScore 3.0


MuseScore {
    version: "2.0"
    description: "Select [top/bottom] or any given level between [2-7] of notes from a chord based on their vertical stack (counting from bottom) in chord(s). Aside functionality (which could be its own plugin probably, but why not here: construct chord or a sequence from a range selection. can be useful under certain circumstances."
    menuPath: "Plugins.Select Chord Levels"
    pluginType: "dialog"
    width:  445
    height: 330

    // Quick Top/Bottom/ 2-7 layers can be selected (only one) by using this plugin and pressing
    // 0 = top
    // 1 = bottom
    // == 2-7 the rest
    // and then the plugin will quit
    // For multiple levels, mouse will need to be used


    function displayMessageDlg(msg) {
        ctrlMessageDialog.text = qsTr(msg);
        ctrlMessageDialog.visible = true;
    }


    // All shortcuts will invoke a function and then quit the plug-in,
    // Clicking buttons will keep dialogue open.

    Keys.onEscapePressed: { // Keypress
        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
    }

    // Create Passage from Range
    Keys.onDigit9Pressed: {
        if (createPassageFromRange())
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
    }

    // Create Chord from Range
    Keys.onDigit8Pressed: {
        if (createChordFromRange())
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
    }


    // Keyboard Shortcuts:
    //
    //
    Keys.onDigit0Pressed: {
        // Top layer

        // [All but Top] if CTRL+0
        if (event.modifiers && Qt.ControlModifier) {
               ctrlCheckBoxOmitTop.checkedState = Qt.Checked
        }  else ctrlCheckBoxLevel1.checkedState = Qt.Checked

        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()

        ctrlCheckBoxTopLevel.checkedState = Qt.Unchecked
        ctrlCheckBoxOmitTop.checkedState = Qt.Unchecked
    }
    Keys.onDigit1Pressed: {
        // Bottom Layer
        // [All but Bottom] if CTRL+1
        if (event.modifiers && Qt.ControlModifier) {
            ctrlCheckBoxOmitBottom.checkedState = Qt.Checked
        }  else ctrlCheckBoxLevel1.checkedState = Qt.Checked

        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()

        ctrlCheckBoxLevel1.checkedState = Qt.Unchecked
        ctrlCheckBoxOmitBottom.checkedState = Qt.Unchecked
    }
    Keys.onDigit2Pressed: {
        ctrlCheckBoxLevel2.checkedState = Qt.Checked
        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        ctrlCheckBoxLevel2.checkedState = Qt.Unchecked
    }
    Keys.onDigit3Pressed: {
        ctrlCheckBoxLevel3.checkedState = Qt.Checked
        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        ctrlCheckBoxLevel3.checkedState = Qt.Unchecked
    }
    Keys.onDigit4Pressed: {
        ctrlCheckBoxLevel4.checkedState = Qt.Checked
        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        ctrlCheckBoxLevel4.checkedState = Qt.Unchecked
    }
    Keys.onDigit5Pressed: {
        ctrlCheckBoxLevel5.checkedState = Qt.Checked
        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        ctrlCheckBoxLevel5.checkedState = Qt.Unchecked
    }
    Keys.onDigit6Pressed: {
        // Check for shift (for omit)
        ctrlCheckBoxOmitTop.checkedState = Qt.Checked
        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        ctrlCheckBoxOmitTop.checkedState = Qt.Unchecked
    }
    Keys.onDigit7Pressed: {
        // Check for shift (for omit)
        ctrlCheckBoxOmitBottom.checkedState = Qt.Checked
        if (selectLevels(false, false))
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        ctrlCheckBoxOmitBottom.checkedState = Qt.Unchecked
    }


    function getAllChordsInRange(chordArray) {
        var cursor = curScore.newCursor();
        cursor.rewind(1);
        var startStaff;
        var endStaff;
        var endTick;

        if (!cursor.segment) { // no selection
            console.log("No valid single-staff region selected.");
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        }

        startStaff = cursor.staffIdx;
        cursor.rewind(2);
        if (cursor.tick === 0) {
            // this happens when the selection includes
            // the last measure of the score.
            // rewind(2) goes behind the last segment (where
            // there's none) and sets tick=0
            endTick = curScore.lastSegment.tick + 1;
        } else {
            endTick = cursor.tick;
        }

        endStaff = cursor.staffIdx;

        for (var staff = startStaff; staff <= endStaff; staff++) {
            for (var voice = 0; voice < 4; voice++) {
                cursor.rewind(1); // sets voice to 0
                cursor.voice = voice; //voice has to be set after goTo
                cursor.staffIdx = staff;

                while (cursor.segment && (cursor.tick < endTick)) {
                    if (cursor.element && cursor.element.type === Element.CHORD) {
                        var graceChords = cursor.element.graceNotes;
                        // Verify this works for grace-notes
                        for (var i = 0; i < graceChords.length; i++) {
                            chordArray.push(graceChords[i]);
                        }

                        // the chord of the notes...
                        chordArray.push(cursor.element);

                    }
                    cursor.next();
                }
            }
        }
    }


    //////////////////////////
    // createPassage
    // Form a passage of notes from a range selection - conceptualized originally as converting a chord to a linear set of notes
    // but why not also allow any range to be the source?
    function createPassageFromRange() {
        var cursor = curScore.newCursor();
        cursor.track = 0;
        cursor.rewind(1);       // 1 = SELECTION_START
                                // 2 = SELECTION_END
        var beginTick = curScore.selection.startSegment.tick;
        var currentStaff = curScore.selection.startStaff;


        var chords = [];
        getAllChordsInRange(chords);
        if (!chords.length) {
            displayMessageDlg(qsTr("No valid range selection on current score! Tsk Tsk."));
            return
        }


        cmd("copy");
        cmd("delete");

        cursor.rewindToTick(beginTick);


        curScore.startCmd();

        // Get pitches out of the chords. Why? To facilitate removal of duplicate pitches
        var pitches = [];
        extrapolatePitchesFromChords(chords, pitches);

        var uniquePitches = [];
        for (var i = 0; i < pitches.length; i++)
            if (pitches.indexOf(pitches[i]) == i)
                uniquePitches.push(pitches[i]);
        uniquePitches.sort();

        cursor.track = 0;
        cursor.setDuration(1, 8);

        for (var idx = 0; idx < uniquePitches.length; idx++) {
            // console.log("addNote(): " + uniquePitches[idx] + "at cursor: " + cursor.tick);
            cursor.addNote(uniquePitches[idx]);
        }

        console.log("Constructing 1/8th note sequence...");
        console.log("Clipboard sequence consists of pitches: " + uniquePitches)

        // Note: Cursor position is not at the last note added, but the next segment afterwards
        // since addNote without the true flag moves forward by default.
        cursor.prev();
        var nextTick = cursor.tick;

        curScore.endCmd();

        var success = curScore.selection.selectRange(beginTick, nextTick, currentStaff, currentStaff+1);

        console.log(success);
        cmd("cut");  // Cut results to clipboard
        cmd("undo"); // 1) Undoing the cut
        cmd("undo"); // 2) Undoing the sequence application as above
        cmd("undo"); // 3) Undoing the original delete - should be back to original state

        var completed = true;
        return completed;
    }




    //////////////////////////
    // createChordFromRange
    // Forms a chord from out of all pitches present within the context of a range-based selection, storing the result
    // as a clipboard item prepared for pasting. The duration is a default quarter-tone
    function createChordFromRange() {

        var cursor = curScore.newCursor();
        cursor.track = 0;
        cursor.rewind(1);       // 1 = SELECTION_START
                                // 2 = SELECTION_END
        var beginTick = curScore.selection.startSegment.tick;
        var currentStaff = curScore.selection.startStaff;

        var chords = [];
        getAllChordsInRange(chords);

        if (!chords.length) {
            displayMessageDlg(qsTr("No valid range selection on current score! Tsk Tsk."));
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        }

        // Copy range selection, then delete it
        cmd("copy");
        cmd("delete");

        cursor.rewindToTick(beginTick);

        curScore.startCmd();
        // Get pitches out of the chords. Why? To facilitate removal of duplicate pitches
        var pitches = [];
        extrapolatePitchesFromChords(chords, pitches);

        // Remove duplicates by hand
        var uniquePitches = [];
        for (var i = 0; i < pitches.length; i++)
            if (pitches.indexOf(pitches[i]) == i)
                uniquePitches.push(pitches[i]);
        uniquePitches.sort();

        console.log("Constructing chord...");
        console.log("Clipboard chord consists of pitches: " + uniquePitches)

        // Start first pitch of chord
        cursor.addNote(uniquePitches[0], false);
        // Continue to add remaining chord's pitches
        for (var pitch = 1; pitch < uniquePitches.length; pitch++)
            cursor.addNote(uniquePitches[pitch], true);


        var nextTick = cursor.tick;

        curScore.endCmd();

        var success = curScore.selection.selectRange(beginTick, nextTick, currentStaff, currentStaff+1);

        cmd("cut");  // Cut results to clipboard
        cmd("undo"); // 1) Undoing the cut
        cmd("undo"); // 2) Undoing the sequence application as above
        cmd("undo"); // 3) Undoing the original delete - should be back to original state

        var completed = true;
        return completed;
    }


    //////////////////
    // extrapolatePitchesFromChords
    // IN:  array of chords
    // OUT: array of pitch integers
    function extrapolatePitchesFromChords (chords, pitches) {
        for (var i=0; i < chords.length; i++) {
            var notes = chords[i].notes;
            // Extrapolate pitches
            for (var ix=0; ix < notes.length; ix++) { // Aside: a chord with one note has length of one
                var note = notes[ix];
                pitches.push(note.pitch);
            }
        }
    }



    function selectLevels(move, deleteDesired) {
        console.log("Starting selectLevels()");
        var operationPerformed = false;

        var levels = [];
        if (ctrlCheckBoxOmitTop.checked) {
            levels.push(7);
        }
        if (ctrlCheckBoxOmitBottom.checked) {
            levels.push(6);
        }
        if (ctrlCheckBoxLevel5.checked) {
            levels.push(5);
        }
        if (ctrlCheckBoxLevel4.checked) {
            levels.push(4);
        }
        if (ctrlCheckBoxLevel3.checked) {
            levels.push(3);
        }
        if (ctrlCheckBoxLevel2.checked) {
            levels.push(2);
        }
        if (ctrlCheckBoxLevel1.checked) {
            levels.push(1);
        }

        // Require a level to be selected when [Selecting]
        if (!levels.length && !move && !ctrlCheckBoxTopLevel.checked) {
            displayMessageDlg(qsTr("No levels(s) checked! Select the level(s) that match your chord stack sizes."));
            return
        }


        var chords = [];
        getAllChordsInRange(chords);
        if (!chords.length) {
            displayMessageDlg(qsTr("No valid range selection on current score! Tsk Tsk."));
            return false
        }


        curScore.startCmd(); // Start collecting undo info.

        // Method: will clear the range selection and begin adding one at a time the notes that correlate with user-checked levels

        var keep = false;
        if (ctrlCheckBoxOmitBottom.checked || ctrlCheckBoxOmitTop.checked) {
            keep = true;
            console.log("Keep selection");
        }

        curScore.selection.clear();

        for (var c = 0; c < chords.length; c++) {
            var notesInChord = chords[c].notes.length;
            // console.log("# of notes in chord # " + (c + 1) + ":" + notesInChord);
            var notesQueuedToDeleteInChord = 0;



            for (var n = 0; n < chords[c].notes.length; n++) {
                for (var j = 0; j < levels.length; j++) {
                    // skip if not in levels
                    if ((levels[j] - 1 != n)  && !keep)
                        continue;
                    // add note to list selection or delete it
                    else {
                        if (deleteDesired)
                            chords[c].remove(chords[c].notes[n]);
                        else curScore.selection.select(chords[c].notes[n], true);
                    }
                }
            }
            // Special handling for absolute top note [notes.length-1] ought to be the index of the top-most note of any given chord-level
            if (ctrlCheckBoxTopLevel.checked) { // Top is checked, add it to list
                if (deleteDesired)
                    chords[c].remove(chords[c].notes[chords[c].notes.length - 1]);
                else curScore.selection.select(chords[c].notes[chords[c].notes.length - 1], true);
            }
            if (ctrlCheckBoxOmitBottom.checked) {
                console.log("Omit Bottom: deselecting...");
                curScore.selection.deselect(chords[c].notes[0]) // chords[c].notes.length - 1]);
            }
            if (ctrlCheckBoxOmitTop.checked) {
                console.log("Omit Top: deselecting...");
                curScore.selection.deselect(chords[c].notes[chords[c].notes.length - 1]);
            }
        }
        // Switch voice of remaining selection if Revoice
        if (move) {
            var cmdVoiceIndex = ctrlComboBoxVoice.currentIndex + 1;
            console.log("selectLevels() is attempting to move selected notes (in selected levels) to layer " + cmdVoiceIndex);
            cmd("voice-" + cmdVoiceIndex);
            console.log("selectLevels() cmd call was executed.");
        }

        curScore.endCmd(); // Finish off the undo record.

        operationPerformed = true;
        console.log("Ending selectLevels()");
        return operationPerformed;
    }


    onRun: {
        console.log("Chord Levels script starting...");

        if (typeof curScore === 'undefined') {
            var msg = "Chord Levels exiting without processing - no current score!";
            console.log(msg);
            displayMessageDlg(msg);
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        }
    }

    Rectangle {
        property alias mouseArea: mouseArea
        // property alias btnDeleteLevels: btnDeleteLevels
        property alias btnRevoiceLevels: btnRevoiceLevels
        property alias btnClose: btnClose
        property alias ctrlHintLabel: ctrlHintLabel
        property alias ctrlMessageDialog: ctrlMessageDialog

        width: 500
        height: 400
//        color: "#e3e3e3"

        MessageDialog {
            id: ctrlMessageDialog
            icon: StandardIcon.Information
            title: "Chord Levels Message"
            text: "Welcome to Chord Levels!"
            visible: false
            onAccepted: {
                visible = false;
            }
        }

        MouseArea {
            id: mouseArea
            anchors.rightMargin: 0
            anchors.bottomMargin: 0
            anchors.leftMargin: 0
            anchors.topMargin: 0
            anchors.fill: parent

            Text {
                id: ctrlStackRangeLabel
                x: 35
                y: 15
                width: 100
                font.underline: true
                text: "Levels:"
            }

            Column
            {
                x: 35
                y: 35

                CheckBox {
                    id: ctrlCheckBoxTopLevel
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("Top")
                        }
                    }
                }
                CheckBox {
                    id: ctrlCheckBoxLevel5
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("5")
                        }
                    }
                }
                CheckBox {
                    id: ctrlCheckBoxLevel4
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("4")
                        }
                    }
                }
                CheckBox {
                    id: ctrlCheckBoxLevel3
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("3")
                        }
                    }
                }
                CheckBox {
                    id: ctrlCheckBoxLevel2
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("2")
                        }
                    }
                }

                CheckBox {
                    id: ctrlCheckBoxLevel1
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("Bottom")
                        }
                    }
                }

            }

            Text {
                id: ctrlStackRangeOmitLabel
                x: 135
                y: 15
                width: 100
                font.underline: true
                text: "Select All, but:"
            }
            Text {
                id: ctrlStackRangeOmitLabel2
                x: 125
                y: 15
                width: 25
                text: "*"
                font.pointSize: 12
            }


            Column
            {
                x: 135
                y: 35
                CheckBox {
                    id: ctrlCheckBoxOmitTop
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("Omit Top")
                        }
                    }
                    onCheckedChanged: {
                        if (ctrlCheckBoxOmitTop.checked || ctrlCheckBoxOmitBottom.checked) {
                            ctrlCheckBoxTopLevel.enabled = false;
                            ctrlCheckBoxLevel1.enabled   = false;
                            ctrlCheckBoxLevel2.enabled   = false;
                            ctrlCheckBoxLevel3.enabled   = false;
                            ctrlCheckBoxLevel4.enabled   = false;
                            ctrlCheckBoxLevel5.enabled   = false;

                            ctrlCheckBoxTopLevel.checked = false;
                            ctrlCheckBoxLevel1.checked   = false;
                            ctrlCheckBoxLevel2.checked   = false;
                            ctrlCheckBoxLevel3.checked   = false;
                            ctrlCheckBoxLevel4.checked   = false;
                            ctrlCheckBoxLevel5.checked   = false;
                        }
                    }
                }

                CheckBox {
                    id: ctrlCheckBoxOmitBottom
                    style: CheckBoxStyle {
                        label: Text {
                            color: "black"
                            text: qsTr("Omit Bottom")
                        }
                    }

                    onCheckedChanged: {
                        if (ctrlCheckBoxOmitTop.checked || ctrlCheckBoxOmitBottom.checked) {
                            ctrlCheckBoxTopLevel.enabled = false;
                            ctrlCheckBoxLevel1.enabled   = false;
                            ctrlCheckBoxLevel2.enabled   = false;
                            ctrlCheckBoxLevel3.enabled   = false;
                            ctrlCheckBoxLevel4.enabled   = false;
                            ctrlCheckBoxLevel5.enabled   = false;

                            ctrlCheckBoxTopLevel.checked = false;
                            ctrlCheckBoxLevel1.checked   = false;
                            ctrlCheckBoxLevel2.checked   = false;
                            ctrlCheckBoxLevel3.checked   = false;
                            ctrlCheckBoxLevel4.checked   = false;
                            ctrlCheckBoxLevel5.checked   = false;
                        }
                        if (!ctrlCheckBoxOmitTop.checked && !ctrlCheckBoxOmitBottom.checked) {
                            ctrlCheckBoxTopLevel.enabled = true;
                            ctrlCheckBoxLevel1.enabled   = true;
                            ctrlCheckBoxLevel2.enabled   = true;
                            ctrlCheckBoxLevel3.enabled   = true;
                            ctrlCheckBoxLevel4.enabled   = true;
                            ctrlCheckBoxLevel5.enabled   = true;

                            ctrlCheckBoxTopLevel.checked = false;
                            ctrlCheckBoxLevel1.checked   = false;
                            ctrlCheckBoxLevel2.checked   = false;
                            ctrlCheckBoxLevel3.checked   = false;
                            ctrlCheckBoxLevel4.checked   = false;
                            ctrlCheckBoxLevel5.checked   = false;
                        }

                    }
                }
            }

//            Text {
//                id: ctrlVoicesLabel
//                x: 350
//                y: 95
//                width: 100
//                text: "Voice:"
//            }

            ComboBox {
                id: ctrlComboBoxVoice
                width: 35
                height: 35
                currentIndex: 1
                x: 395
                y: 55
                model: ListModel {
                    id: cbVoiceItems
                    ListElement { text: "1"; color: "Blue" }
                    ListElement { text: "2"; color: "Green" }
                    ListElement { text: "3"; color: "Brown" }
                    ListElement { text: "4"; color: "Purple" }
                }
            }

            /*
            Button {
                id: btnDeleteLevels
                x: 280
                y: 95
                width: 150
                height: 35
                text: qsTr("Delete")
                onClicked: {
                    if (selectLevels(false, true)) {
                        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
                    }
                }
            }
            */

            Button {
//                style: ButtonStyle {
//                        label: Text {
//                            color: "white"
//                            text: qsTr("Bottom")
//                        }
//                    }
                id: btnRevoiceLevels
                x: 280
                y: 55
                width: 110
                height: 35
                text: qsTr("Revoice")
                onClicked: {
                    if (selectLevels(true, false)) {
                        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
                    }
                }
            }

            Button {
                id: btnSelectLevels
                x: 280
                y: 15
                width: 150
                height: 35
                text: qsTr("Select Only")
                focus: true;
                onClicked: {
                    if (selectLevels(false, false)) {
                        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
                    }
                }
            }


            Button {
                id: btnClose
                x: 50
                y: 280
                width: 150
                height: 35
                text: qsTr("Close")
                onClicked: {
                    console.log("... exiting Chord Levels Select ...");
                    (typeof(quit) === 'undefined' ? Qt.quit : quit)()
                }
            }

        /*
            Button {
                id: btnCreateChord
                x: 280
                y: 135
                width: 150
                height: 35
                text: qsTr("Create Chord")
                onClicked: {
                    if (createChordFromRange()) {
                        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
                    }
                }
            }
        */



            Text {
                id: ctrlHintLabel
                x: 20
                y: 135
                width: 250
                text: qsTr("Use checkboxes for multiple selection - keyboard shortcuts for one only.\n* Control modifier applies only to top or bottom levels of \"Select all but\"")
                font.italic: true
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }

            Text {
                id: ctrlHintLabel2
                x: 298
                y: 100
                width: 250
                text: qsTr("Selection Shortcuts")
                font.italic: false
                font.underline: true
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }

            Text {
                id: ctrlHintLabel3
                x: 320
                y: 135
                width: 250
                text: qsTr("[0]     Top\n[1]     Bottom")
                font.italic: false
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }
            Text {
                id: ctrlHintLabel33
                x: 310
                y: 120
                width: 250
                text: "*"
                font.italic: false
                wrapMode: Text.WordWrap
                font.pointSize: 12
            }
            Text {
                id: ctrlHintLabel33b
                x: 320
                y: 120
                width: 250
                text: "[CTRL Modifier]"
                font.italic: true
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }




            Text {
                id: ctrlHintLabel333
                x: 320
                y: 163
                width: 250
                text: qsTr("[2-5]  Others")
                font.italic: false
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }

            Text {
                id: ctrlHintLabel99
                x: 298
                y: 200
                width: 250
                text: qsTr("Formation Shortcuts")
                font.italic: false
                font.underline: true
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }


            Text {
                id: ctrlHintLabel4a
                x: 300
                y: 225
                width: 250
                text: qsTr("[8]")
                font.italic: false
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }
            Button {
                id: btnFormChord
                x: 320
                y: 220
                width: 110
                height: 25
                text: qsTr("Form Chord")
                focus: true;
                onClicked: {
                    if (createChordFromRange())
                        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
                }
            }

            Text {
                id: ctrlHintLabel4b
                x: 300
                y: 255
                width: 250
                text: qsTr("[9]")
                font.italic: false
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }

            Button {
                id: btnFormSequence
                x: 320
                y: 250
                width: 110
                height: 25
                text: qsTr("Form Sequence")
                focus: true;
                onClicked: {
                    if (createPassageFromRange())
                        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
                }
            }




            Text {
                id: ctrlHintLabel5
                x: 20
                y: 210
                width: 220
                text: qsTr("Formation shortcuts create a chord (quarter) or passage (eighth) and save results into the clipboard for future pasting.")
                font.italic: true
                // color: "black"
                wrapMode: Text.WordWrap
                font.pointSize: 10
            }

        }

    }
}
