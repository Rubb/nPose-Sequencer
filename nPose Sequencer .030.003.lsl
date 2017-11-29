

key kQuery;     //used for dataserver to sort out if this is the response we looking for
integer iLine = 0;      //notecard line number

float posePause = 0.0;  //used to set the pose time for the current pose
string loadedCard;      //name of the notecard which is sent to dataserver for reading. will only change if someone selects another sequence to run
string cardToRun = "";  
integer loopTo = 0;     //line number where LOOPTO occurs.  if no LOOPTO line in notecard this remains at line 0
integer loopToSkipper = 0; //used in isPaused state to move in front of or one after LOOPTO depending on if prev or next brings us to this line.



default{
    state_entry(){
    }
    
    link_message(integer sNum, integer num, string str, key id){
        if (num == -2241){
            //nPose has sent us notification that we need to do a sequence
            //do some initialization before we read the notecard, grab the notecard name to process
            iLine = 0;
            loopTo = 0;
            loadedCard = str;
            state isRunning;
            kQuery = llGetNotecardLine(loadedCard, iLine);
        }else if (num == 34334){
            //just a memory check initiated by nPose notecard.  typically used for initial setup
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
                 + ",Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
    }

    changed(integer change){
        if (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()){   //check to see if anyone is still seated
            //all are off so do some cleanup and turn off the timer
            iLine = 0;
        }
    }
}





state isRunning{
    state_entry(){
        //we got here because we need to start a new sequence so read the first line and let'r rip
        kQuery = llGetNotecardLine(loadedCard, iLine);
    }
    
    link_message(integer sNum, integer num, string str, key id){
        if (num == -2241){
            //nPose has sent us notification that we need to do a new sequence
            //do some initialization before we read the notecard, grab the notecard name to process
            iLine = 0;
            loopTo = 0;
            loadedCard = str;
            kQuery = llGetNotecardLine(loadedCard, iLine);
        }else if (num == -2240){
            //commands sent from nPose to do other stuff
            if (str == "Pause") {
                //pause command does just that, it pauses the timer and holds the corrent pose
                llSetTimerEvent(0.0);
                state isPaused;
            }else if (str == "Next"){
                //next will move to the next sequence
                iLine += 1;
                kQuery = llGetNotecardLine(loadedCard, iLine);
            }else if (str == "Prev"){
                //prev moves to the previous line in the notecard
                iLine -= 1;
                //check bounds of prev clicks and do not let iLine go more than -1
                if (iLine <= 0){
                    iLine = 0;
                }
                kQuery = llGetNotecardLine(loadedCard, iLine);
            }
        }else if (num == 200){
            //here is the check to see if nPose wants to move to a normal non-sequenced pose set
            if (cardToRun != str){
                //if the pose set does not match the one the sequencer is running, stop the timer
                llSetTimerEvent(0.0);
                state default;
            }
        }else if (num == 34334){
            //just a memory check initiated by nPose notecard.  typically used for initial setup
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
                 + ",Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
    }

    dataserver(key query_id, string data){
        if (query_id == kQuery){
            if (data == EOF){
                llSetTimerEvent(0.0);
            }else{
                list thisLine = llParseString2List(data,["|"],[]);
                posePause = llList2Float(thisLine, 0);
                cardToRun = llList2String(thisLine, 1);
                if (llList2String(thisLine,0) == "LOOPTO"){
                    //if it is LOOPTO line in notecard, set our LOOPTO variable to this line number for future use
                    loopTo = iLine;
                    iLine += 1; //pass over the LOOPTO line and read the next one instead
                    kQuery = llGetNotecardLine(loadedCard, iLine);
                //check if this notecard line is LOOP
                }else if (llList2String(thisLine,0) == "LOOP"){
                    //we have a LOOP command in this line so it is time to go back to the LOOPTO line number
                    iLine = loopTo;
                    if (loopTo > 0){
                        iLine = loopTo + 1;
                    }
                    kQuery = llGetNotecardLine(loadedCard, iLine);
                }
                if (cardToRun != ""){ //we've sorted out which line to use to fire the next sequence.  do it.
                    llSetTimerEvent(posePause);
                    if (llSubStringIndex(cardToRun, "BTN:") == 0){
                        llMessageLinked(LINK_SET,207, cardToRun, NULL_KEY);
                    }else if (llSubStringIndex(cardToRun, "SET:") == 0){
                        llMessageLinked(LINK_SET,200, cardToRun, NULL_KEY);
                    }
                }
            }
        }
    }

    timer(){
        //stop the timer just in case this script is slow so we ensure it only fires when we want it to
        llSetTimerEvent(0.0);
        //read the next line number
        iLine += 1;
        kQuery = llGetNotecardLine(loadedCard, iLine);
    }
   
    changed(integer change){
        if (change & CHANGED_LINK){
            if (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()){   //check to see if anyone is still seated
                //all are off so do some cleanup and turn off the timer
                iLine = 0;
                llSetTimerEvent(0.0);
                state default;
            }
        }
    }
}







state isPaused{
    link_message(integer sNum, integer num, string str, key id){
        if (num == -2241){
            //nPose has sent us notification that we need to do a new sequence
            //do some initialization before we read the notecard, grab the notecard name to process
            iLine = 0;
            loopTo = 0;
            loadedCard = str;
            state isRunning;
        }else if (num == -2240){
            //commands sent from nPose to do other stuff
            if (str == "Next"){
                //next will move to the next sequence
                iLine += 1;
                loopToSkipper = 1; //offset for the LOOPTO line to get past it
                kQuery = llGetNotecardLine(loadedCard, iLine);
            }else if (str == "Prev"){
                //prev moves to the previous line in the notecard
                iLine -= 1;
                loopToSkipper = -1;  //offset for the LOOPTO line to get past it
                //check bounds of prev clicks and do not let iLine go more than -1
                if (iLine <= 0){
                    iLine = 0;
                }
                kQuery = llGetNotecardLine(loadedCard, iLine);
            }else if (str == "Resume"){
                //resume is the anti-pause and will start the paused timer at the current pose
                state isRunning;
            }
        }else if (num == 200){
            //here is the check to see if nPose wants to move to a normal non-sequenced pose set
            if (cardToRun != str){
                //if the pose set does not match the one the sequencer is running, stop the timer
                llSetTimerEvent(0.0);
                state default;
            }
        }else if (num == 34334){
            //just a memory check initiated by nPose notecard.  typically used for initial setup
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
                 + ",Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
    }

    dataserver(key query_id, string data){
        if (query_id == kQuery){
            if (data == EOF){
                llSetTimerEvent(0.0);
            }else{
                list thisLine = llParseString2List(data,["|"],[]);
                posePause = llList2Float(thisLine, 0);
                cardToRun = llList2String(thisLine, 1);
                if (llList2String(thisLine,0) == "LOOPTO"){
                    //if it is LOOPTO line in notecard, set our LOOPTO variable to this line number for future use
                    loopTo = iLine;
                    iLine += loopToSkipper; //pass over the LOOPTO line and read the next one instead
                    kQuery = llGetNotecardLine(loadedCard, iLine);
                    //check if this notecard line is LOOP
                }else if (llList2String(thisLine,0) == "LOOP"){
                    //we have a LOOP command in this line so it is time to go back to the LOOPTO line number
                    iLine = loopTo;
                    if (loopTo > 0){
                        iLine = loopTo + 1;
                    }
                    kQuery = llGetNotecardLine(loadedCard, iLine);
                }
                if (cardToRun != ""){ //we've sorted out which line to use to fire the next sequence.  do it.
                    if (llSubStringIndex(cardToRun, "BTN:") == 0){
                        llMessageLinked(LINK_SET,207, cardToRun, NULL_KEY);
                    }else if (llSubStringIndex(cardToRun, "SET:") == 0){
                        llMessageLinked(LINK_SET,200, cardToRun, NULL_KEY);
                    }
                }
            }
        }
    }

    changed(integer change){
        if (change & CHANGED_LINK){
            if (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()){   //check to see if anyone is still seated
                //all are off so do some cleanup and turn off the timer
                iLine = 0;
                llSetTimerEvent(0.0);
                state default;
            }
        }
    }
}
