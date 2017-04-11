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

function PlayerController FindPlayer(string NameOrID)
{
	local Controller C;
     local PlayerController PC;
	
	if ( NameOrID == "" || NameOrID == "0" || NameOrID ~= "WebAdmin" )
		return none;
		
	for ( C = Level.ControllerList; C != None; C = C.NextController ) {
        PC = PlayerController(C);
		if ( PC != None && C.PlayerReplicationInfo != None ) {
			if ( (C.PlayerReplicationInfo.PlayerID > 0 && String(C.PlayerReplicationInfo.PlayerID) == NameOrID)
					|| C.PlayerReplicationInfo.PlayerName ~= NameOrID )
            {
				return PC;
            }
		}
	}
	return none;
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
