// Custom Interaction for displaying current vote status
class VHInteraction extends Interaction
    config(user);

var transient VHReplicationInfo VHRI;

var float FadeTime;
var config float PosY; // vertical position of vote status message (it will be centered horizontally)
var localized String strVoteInProgress, strVotePassed, strVoteFailed;
var localized String strVotedYes, strVotedNo;
var localized String strKeyToVoteYes, strKeyToVoteNo, strNoKeySetYes, strNoKeySetNo;


var String Status, VoteName;
var String strKeyBindYes, strKeyBindNo;
var bool bKeyBindYesFound, bKeyBindNoFound;

var color colStatus, colName, colPassed, colFailed;
var byte Alpha;

var transient bool bVotePassed;
var transient int YesVotes, NoVotes;


function UpdateVotes(int y, int n)
{
    YesVotes = y;
    NoVotes = n;
}

function VoteStarted(String DisplayString)
{
    if ( IsInState('InProgress') )
        GotoState(''); // wtf?

    VoteName = DisplayString;
    YesVotes = 1; //initiator
    NoVotes = 0;
    GotoState('InProgress');
}

function VoteEnded(bool bPassed)
{
    bVotePassed = bPassed;
    GotoState('Closing');
}

// returns key name, that is bound to the given alias
// returns an empty string, if not key bound
function string GetBoundKey(string Alias)
{
    local GUIController GC;
    local array<string> BindKeyNames;
    local array<string> LocalizedBindKeyNames;

    GC = GUIController(ViewportOwner.GUIController);
    if ( GC == none )
        return "";

    GC.GetAssignedKeys(Alias, BindKeyNames, LocalizedBindKeyNames);

    if ( BindKeyNames.length == 0 )
        return "";

    if ( LocalizedBindKeyNames[0] != "" )
        return LocalizedBindKeyNames[0];

    return BindKeyNames[0];
}

// bind command to a key, if it is unassigned
function bool BindIfUnassigned(string BindKeyName, string BindKeyValue)
{
    local string cmd;

    cmd = ViewportOwner.Actor.ConsoleCommand("KEYBINDING" @ BindKeyName);
    if ( cmd ~= BindKeyValue )
        return true;
    else if ( cmd == "" ) {
        ViewportOwner.Actor.ConsoleCommand("set Input" @ BindKeyName @ BindKeyValue);
        return true;
    }
    else
        return false;
}



state Closing
{
    function BeginState()
    {
        if ( bVotePassed ) {
            Status = strVotePassed;
            colStatus = colPassed;
            colName = colPassed;
        }
        else {
            Status = strVoteFailed;
            colStatus = colFailed;
            colName = colFailed;
        }
        bRequiresTick = true;
        FadeTime = default.FadeTime;

        bVisible=true;
    }

    function EndState()
    {
        bRequiresTick = false;
    }

    function VoteEnded(bool bPassed)
    {
        bVotePassed = bPassed;
        BeginState();
    }


    function Tick(float DeltaTime)
    {
        FadeTime -= DeltaTime;
        if ( FadeTime <= 0 ) {
            bVisible = false;
            GotoState('');
        }
        else {
            Alpha = FadeTime / default.FadeTime * default.Alpha;
        }
    }
}

state InProgress
{
    function BeginState()
    {
        local string s;

        Status = strVoteInProgress;
        colStatus = default.colStatus;
        colName = default.colName;

        if ( !bKeyBindYesFound ) {
            BindIfUnassigned("F3", "MUTATE VOTE YES")
                && BindIfUnassigned("Y", "MUTATE VOTE YES")
                && BindIfUnassigned("NumPad1", "MUTATE VOTE YES");
            strKeyBindYes = strKeyToVoteYes;
            if ( InStr(strKeyBindYes, "%k") != -1 ) {
                s = GetBoundKey("MUTATE VOTE YES");
                if ( s != "" ) {
                    ReplaceText(strKeyBindYes, "%k", s);
                    bKeyBindYesFound = true;
                }
                else strKeyBindYes = strNoKeySetYes;
            }
            else bKeyBindYesFound = true;
        }
        if ( !bKeyBindNoFound ) {
            BindIfUnassigned("F2", "MUTATE VOTE NO")
                && BindIfUnassigned("N", "MUTATE VOTE NO")
                && BindIfUnassigned("NumPad0", "MUTATE VOTE NO");
            strKeyBindNo = strKeyToVoteNo;
            if ( InStr(strKeyBindNo, "%k") != -1 ) {
                s = GetBoundKey("MUTATE VOTE NO");
                if ( s != "" ) {
                    ReplaceText(strKeyBindNo, "%k", s);
                    bKeyBindNoFound = true;
                }
                else strKeyBindNo = strNoKeySetNo;
            }
            else bKeyBindNoFound = true;
        }
        strVotedYes = default.strVotedYes $ YesVotes $ strKeyBindYes;
        strVotedNo = default.strVotedNo $ NoVotes $ strKeyBindNo;

        Alpha=255;
        bVisible=true;
    }

    function UpdateVotes(int y, int n)
    {
        if ( YesVotes != y ) {
            YesVotes = y;
            strVotedYes = default.strVotedYes $ y $ strKeyBindYes;
        }
        if ( NoVotes != n ) {
            NoVotes = n;
            strVotedNo = default.strVotedNo $ n $ strKeyBindNo;
        }
    }

    function DrawAdditionalInfo(Canvas canvas, float y)
    {
        local float TextWidth, TextHeight;
        local float x;
        canvas.Font = class'ROHUD'.Static.LoadSmallFontStatic(6);

        // voted yes
        canvas.DrawColor = colPassed;
        canvas.DrawColor.A = Alpha;
        canvas.StrLen(strVotedYes, TextWidth, TextHeight);
        x = (canvas.ClipX - TextWidth) * 0.5;
        canvas.SetPos(x, y);
        canvas.DrawTextClipped(strVotedYes);

        //voted no
        y += TextHeight;
        canvas.DrawColor = colFailed;
        canvas.DrawColor.A = Alpha;
        canvas.StrLen(strVotedNo, TextWidth, TextHeight);
        x = (canvas.ClipX - TextWidth) * 0.5;
        canvas.SetPos(x, y);
        canvas.DrawTextClipped(strVotedNo);
    }

}

function PostRender(Canvas canvas)
{
    local float TextWidth, TextHeight, vMargin;
    local float x, y;

    // vote status
    canvas.DrawColor = colStatus;
    canvas.DrawColor.A = Alpha;
    canvas.Font = class'ROHUD'.Static.LoadSmallFontStatic(5);
    canvas.StrLen(StripColor(Status), TextWidth, TextHeight);
    y = canvas.ClipY * PosY;
    x = (canvas.ClipX - TextWidth) * 0.5;
    canvas.SetPos(x, y);
    canvas.DrawTextClipped(Status);

    //vMargin = TextHeight * 0.25;
    vMargin = 0;
    //vote name
    y += TextHeight + vMargin;
    canvas.DrawColor = colName;
    canvas.DrawColor.A = Alpha;
    canvas.Font = class'ROHUD'.Static.LoadSmallFontStatic(1);
    canvas.StrLen(StripColor(VoteName), TextWidth, TextHeight);
    x = (canvas.ClipX - TextWidth) * 0.5;
    canvas.SetPos(x, y);
    canvas.DrawTextClipped(VoteName);

    //additional info
    y += TextHeight + vMargin;
    DrawAdditionalInfo(canvas, y);
}

event NotifyLevelChange()
{
    Master.RemoveInteraction(self);
    if ( VHRI != none ) {
        VHRI.myInteraction = none;
        VHRI.Destroy();
        VHRI = none;
    }
}

function DrawAdditionalInfo(Canvas canvas, float y) {}

static final function string StripColor(string s)
{
    local int p;

    p = InStr(s,chr(27));
    while ( p>=0 )
    {
        s = left(s,p)$mid(S,p+4);
        p = InStr(s,Chr(27));
    }

    return s;
}


defaultproperties
{
    FadeTime=5.0
    PosY=0.1

    bVisible=false
    bActive=false // no need to get use input
    bRequiresTick=false
    Alpha=255

    colStatus=(B=127,G=127,R=127,A=255)
    colName=(B=27,G=200,R=200,A=255)
    colPassed=(B=0,G=200,R=0,A=255)
    colFailed=(B=0,G=0,R=200,A=255)

    strVoteInProgress="VOTE IN PROGRESS"
    strVotePassed="VOTE PASSED"
    strVoteFailed="VOTE FAILED"
    strVotedYes="YES = "
    strVotedNo="NO = "
    strKeyToVoteYes=" (press %k to vote)"
    strKeyToVoteNo=" (press %k to vote)"
    strNoKeySetYes=" (type MUTATE VOTE YES in console to vote)"
    strNoKeySetNo=" (type MUTATE VOTE NO in console to vote)"
}
