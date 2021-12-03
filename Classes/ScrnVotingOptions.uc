class ScrnVotingOptions extends Info
    abstract;

var ScrnVotingHandlerMut VotingHandler;

var string DefaultGroup; // in cases of MUTATE VOTE GROUP KEY VALUE
var bool bAcceptsGlobalVotes; // should voting handler call GetVoteIndex(), if vote has no group?

var array <localized string> HelpInfo;
var array <localized string> GroupInfo;
var protected bool bHelpPrepared;


var array <string> TrueStrings, FalseStrings;

var localized string strRestartRequired;
var localized string strOptionDisabled;
var localized string strNotAvaliableATM;
var localized string strPlayerNotFound;



const VOTE_UNKNOWN = -1;
const VOTE_ILLEGAL = -2;
const VOTE_NOEFECT = -3;
const VOTE_LOCAL   = -10;


function Destroyed()
{
    if ( VotingHandler != none )
        VotingHandler.RemoveVotingOptions(self.class);

    super.Destroyed();
}

/*
    This function is called by VotingHandler immediatelly after the spawn.
    It should register the voting groups for GetGroupVoteIndex() callings.
*/
function InitGroups()
{
    if ( DefaultGroup == "" )
        bAcceptsGlobalVotes = true;
    else {
        VotingHandler.RegisterGroup(DefaultGroup, self);
        bAcceptsGlobalVotes = false;
    }
}

/*
    Function must return VOTE_UNKNOWN if this class doesn't recognizes the Key
    If Key is recognized, but value is incorrect, return VOTE_ILLEGAL
    If value is already set, or can not vote at the current moment, return VOTE_NOEFECT.
    If Key is correct, but no vote should be done (e.g. displaying additional help on command)
        return VOTE_LOCAL

    Keys are case-insensitive and are already passed in upper case.
*/
function int GetVoteIndex(PlayerController Sender, string Key, out string Value, out string VoteInfo)
{
    return VOTE_UNKNOWN;
}

function int GetGroupVoteIndex(PlayerController Sender, string Group, string Key, out string Value, out string VoteInfo)
{
    return VOTE_UNKNOWN;
}

function ApplyVoteValue(int VoteIndex, string VoteValue);

// returns 1 (true), 0 (false) or -1 (error)
function int TryStrToBool(string str)
{
    local int i;

    for ( i = 0; i < TrueStrings.Length; ++i ) {
        if ( str ~= TrueStrings[i] ) {
            return 1;
        }
    }
    for ( i = 0; i < FalseStrings.Length; ++i ) {
        if ( str ~= FalseStrings[i] ) {
            return 0;
        }
    }

    return -1;
}

static function int TryStrToBoolStatic(string str)
{
    local int i;

    for ( i = 0; i < default.TrueStrings.Length; ++i ) {
        if ( str ~= default.TrueStrings[i] ) {
            return 1;
        }
    }
    for ( i = 0; i < default.FalseStrings.Length; ++i ) {
        if ( str ~= default.FalseStrings[i] ) {
            return 0;
        }
    }

    return -1;
}

function SendPlayerList(PlayerController Sender)
{
    local array<PlayerReplicationInfo> AllPRI;
    local PlayerController PC;
    local int i;

    Level.Game.GameReplicationInfo.GetPRIArray(AllPRI);
    for (i = 0; i<AllPRI.Length; i++) {
        PC = PlayerController(AllPRI[i].Owner);
        if( PC != none && AllPRI[i].PlayerName != "WebAdmin")
            Sender.ClientMessage(Right("   "$AllPRI[i].PlayerID, 3)$")"
                //@ PC.GetPlayerIDHash()
                @ AllPRI[i].PlayerName);
    }
}

function string GetPlayerName(PlayerReplicationInfo PRI)
{
    return PRI.PlayerName;
}

function PlayerController FindPlayerByID(int id)
{
    local Controller C;
    local PlayerReplicationInfo PRI;

    if ( id == 0 )
        return none;

    for ( C = Level.ControllerList; C != none; C = C.NextController ) {
        PRI = C.PlayerReplicationInfo;
        if ( PRI == none )
            continue;

        if ( PRI.PlayerID == id && PlayerController(C) != none ) {
            return PlayerController(C);
        }
    }
}

function PlayerController FindPlayerByName(string Keyword, optional bool bPartial, optional PlayerController Sender)
{
    local Controller C;
    local PlayerController PC, MatchedPC;
    local PlayerReplicationInfo PRI;
    local string s;
    local array<string> matched;
    local int i;

    if ( Keyword == "" )
        return none;

    bPartial = bPartial && len(Keyword) >= 3;  // require at least 3 letters for partial search

    Keyword = caps(Keyword);
    for ( C = Level.ControllerList; C != none; C = C.NextController ) {
        PRI = C.PlayerReplicationInfo;
        if ( PRI == none || PRI.PlayerName == "WebAdmin" )
            continue;
        PC = PlayerController(C);
        if ( PC == none )
            continue;

        s = caps(GetPlayerName(PRI));
        if ( s == Keyword ) {
            return PC;
        }
        else if ( bPartial && InStr(s, Keyword) != -1 ) {
            matched[matched.length] = s;
            MatchedPC = PC;
        }
    }
    if ( matched.length == 1 ) {
        return MatchedPC;
    }
    if ( Sender != none && matched.length > 0 ) {
        for ( i = 0; i < matched.length; ++i ) {
            Sender.ClientMessage(VotingHandler.ParseHelpLine("%r" $ Repl(matched[i], Keyword, "%g"$Keyword$"%r")));
        }
    }
    return none;
}

function PlayerController FindPlayer(string NameOrID, optional PlayerController Sender)
{
    local int id;

    if ( NameOrID == "" || NameOrID == "0" || NameOrID ~= "WebAdmin" )
        return none;

    id = int(NameOrID);
    if ( id > 0 ) {
        return FindPlayerByID(id);
    }
    return FindPlayerByName(NameOrID, Sender != none, Sender);
}

function SendGroupHelp(PlayerController Sender, string Group)
{
    local int i;

    if ( !bHelpPrepared ) {
        bHelpPrepared = true;
        for ( i=0; i<GroupInfo.length; ++i ) {
            GroupInfo[i] = VotingHandler.ParseHelpLine(GroupInfo[i]);
        }
    }

    for ( i=0; i<GroupInfo.length; ++i )
        Sender.ClientMessage(GroupInfo[i]);
}


defaultproperties
{
    TrueStrings(0)="ON"
    TrueStrings(1)="TRUE"
    TrueStrings(2)="1"
    TrueStrings(3)="YES"
    TrueStrings(4)="ENABLE"

    FalseStrings(0)="OFF"
    FalseStrings(1)="FALSE"
    FalseStrings(2)="0"
    FalseStrings(3)="NO"
    FalseStrings(4)="DISABLE"

    strRestartRequired="Map restart required to apply changes"
    strOptionDisabled="Voting option is disabled on the server"
    strNotAvaliableATM="Voting option is not avaliable at this moment"
    strPlayerNotFound="Player with a given ID or name does not exist"
}
