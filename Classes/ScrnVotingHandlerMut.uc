class ScrnVotingHandlerMut extends Mutator
    Config(ScrnVoting);

var globalconfig int VoteCountDown;
var globalconfig float VotePercent, VotePercentCountDown;

const VERSION = 40600;
var localized string strVersion;

var protected bool bVoteInProgress;
var protected int VoteSecondsLeft;
var protected array <PlayerController> VotersYes, VotersNo;

var localized string strVoteInitiated, strVotePassed, strVoteFailed, strVoteFailedInitiator, strVoteFailedPlayer, strVoteTimeout,
    strVoteInProgress, strNoVoteInProgress, strAlreadyVoted, strVoteUnknown, strVoteIllegal, strVoteHasNoEffect,
    strForcedByAdmin, strVotedYes, strVotedNo, strVoteStatus, strSpectatorsCantVote, strOtherTeamVote;
var localized string strTimeout, strPlayerBlocked;

var string VoteInfo; // user-friendly information about current vore
var protected int VoteIndex;
var protected string VoteValue; // value to be set, if vote passes
var protected ScrnVotingOptions CurrentVotingObject; //objects that controls current vote value
var transient PlayerController VoteInitiator;
var transient TeamInfo VotedTeam;
var PlayerController TeamCaptains[2];
var transient PlayerController VotedPlayer;
var protected transient bool bVotedPlayer; // if true, VotedPlayer is used in the current vote

var protected array<ScrnVotingOptions> VotingOptions;

var array <localized string> HelpInfo;
var private bool bHelpPrepared;

var class<VHReplicationInfo> VHReplicationInfoClass;
var VHReplicationInfo VHRI;

var byte VoteID;

var globalconfig float VoteCoolDown;
var PlayerController FailedVoter;
var float FailedVoterBlockTime;  // FailedVoter is unable to start a new vote till this time

// Players who can't start voting. Can be used by voting options
var array<PlayerController> BlockedVoters;

struct SVoteGroup
{
    var String GroupName;
    var ScrnVotingOptions VO;
};
var array<SVoteGroup> VoteGroups;

static function string GetVersionStr()
{
    local String msg, s;
    local int v, sub_v;

    msg = default.strVersion;
    v = VERSION / 100;
    sub_v = VERSION % 100;

    s = String(int(v%100));
    if ( len(s) == 1 )
        s = "0" $ s;
    if ( sub_v > 0 )
        s @= "(BETA "$sub_v$")";
    ReplaceText(msg, "%n", s);

    s = String(v/100);
    ReplaceText(msg, "%m",s);

    return msg;
}

function Mutate(string MutateString, PlayerController Sender)
{
    if ( MutateString ~= "vote" )
        Vote("", Sender);
    else if ( left(MutateString, 5) ~= "vote " )
        Vote(Right(MutateString, len(MutateString)-5), Sender);
    else {
        super.Mutate(MutateString, Sender);

        if ( MutateString ~= "version" )
            Sender.ClientMessage(GetVersionStr());
    }
}

static function ScrnVotingHandlerMut GetVotingHandler(GameInfo Game)
{
    local Mutator mut;

    for ( mut = Game.BaseMutator; mut != none; mut = mut.NextMutator ) {
        if ( ScrnVotingHandlerMut(mut) != none )
            return ScrnVotingHandlerMut(mut);
    }

    return none;
}

function ScrnVotingOptions AddVotingOptions(class<ScrnVotingOptions> VO_Class)
{
    local int i;
    local ScrnVotingOptions VO;

    // don't add same class twice
    for ( i=0; i < VotingOptions.length; ++i ) {
        if ( VotingOptions[i].class == VO_Class )
            return VotingOptions[i];
    }

    VO = spawn(VO_Class, self);
    if ( VO != none ) {
        VO.VotingHandler = self;
        VotingOptions[VotingOptions.length] = VO;
        VO.InitGroups();
    }
    return VO;
}

function RemoveVotingOptions(class<ScrnVotingOptions> VO_Class, optional bool bChildsToo)
{
    local int i, j;

    for ( i=0; i < VotingOptions.length; ++i ) {
        if ( VotingOptions[i].class == VO_Class || (bChildsToo && ClassIsChildOf(VotingOptions[i].class, VO_Class)) ) {
            // unregister groups too
            for ( j=0; j<VoteGroups.length; ++j) {
                if ( VoteGroups[j].VO == VotingOptions[i] )
                    VoteGroups.remove(j--, 1);
            }
            VotingOptions.remove(i--, 1);
        }
    }
}

function ScrnVotingOptions GetGroupOptions(string GroupName)
{
    local int i;

    for ( i=0; i<VoteGroups.length; ++i ) {
        if ( VoteGroups[i].GroupName ~= GroupName )
            return VoteGroups[i].VO;
    }
    return none;
}

function RegisterGroup(string GroupName, ScrnVotingOptions VO)
{
    local int i;

    if ( InStr(GroupName, " ") != -1 ) {
        warn("Voting group can not have spaces: '" $ GroupName $ "'");
        return;
    }

    if ( GetGroupOptions(GroupName) != none )
        return; // already registered

    i = VoteGroups.length;
    VoteGroups.insert(i, 1);
    VoteGroups[i].GroupName = GroupName;
    VoteGroups[i].VO = VO;
}


static function string Trim(string str)
{
    local int l;

    l = len(str);

    while ( l > 0 && left(str,1) == " " )
        str = right(str, --l);

    while ( l > 0 && right(str,1) == " " )
        str = left(str, --l);

    return str;
}



function bool IsVoteInProgress()
{
    return bVoteInProgress;
}

function string GetVoteStatus(optional PlayerController Voter, optional bool bVotedYes)
{
    local string result;

    if ( !bVoteInProgress )
        return strNoVoteInProgress;

    if ( Voter != none && Voter.PlayerReplicationInfo != none ) {
        if ( bVotedYes )
            result = strVotedYes;
        else
            result = strVotedNo;
        ReplaceText(result, "%p", Voter.PlayerReplicationInfo.PlayerName);
    }
    else {
        result = strVoteStatus;
    }
    ReplaceText(result, "%v", VoteInfo);
    ReplaceText(result, "%y", String(VotersYes.length));
    ReplaceText(result, "%n", String(VotersNo.length));

    return result;
}

// returns number of players who are able to vote
function int MaxVoters()
{
    local int result;

    if ( VotedTeam != none )
        result = VotedTeam.Size;
    else
        result = Level.Game.NumPlayers;

    return max(result, 1);
}

function Vote(string VoteString, PlayerController Sender)
{
    local int i, idx;
    local string k, v, g;
    local ScrnVotingOptions VO;

    if ( Sender == none || Sender.PlayerReplicationInfo == none )
        return; // wtf?

    VoteString = caps(Trim(VoteString));

    if ( VoteString == "" || VoteString == "HELP" || VoteString ~= "INFO"  || VoteString ~= "?") {
        SendHelp(Sender);
    }
    else if ( VoteString == "STATUS" ) {
        Sender.ClientMessage(GetVoteStatus());
    }
    else if ( Sender.PlayerReplicationInfo.bOnlySpectator && !Sender.PlayerReplicationInfo.bAdmin ) {
        Sender.ClientMessage(strSpectatorsCantVote);
    }
    else if ( VoteString == "YES" || VoteString == "TRYYES" ) {
        if ( bVoteInProgress ) {
            if ( Sender.PlayerReplicationInfo.bAdmin ) {
                VotePassed(Sender.PlayerReplicationInfo.PlayerName);
                return;
            }
            else if ( VotedTeam != none ) {
                if ( VotedTeam != Sender.PlayerReplicationInfo.Team ) {
                    if ( VoteString != "TRYYES" )
                        Sender.ClientMessage(strOtherTeamVote);
                    return;
                }
                else if ( VotedTeam.TeamIndex < 2 && TeamCaptains[VotedTeam.TeamIndex] == Sender ) {
                    VotePassed(Sender.PlayerReplicationInfo.PlayerName);
                    return;
                }
            }

            for ( i = 0; i < VotersNo.length; i++ ) {
                if ( VotersNo[i] == Sender ) {
                    VotersNo.remove(i, 1);
                    break;
                }
            }
            for ( i = 0; i < VotersYes.length; i++ ) {
                if ( VotersYes[i] == Sender ) {
                    Sender.ClientMessage(strAlreadyVoted);
                    return;
                }
            }
            VotersYes[VotersYes.length] = Sender;
            BroadcastMessage(GetVoteStatus(Sender, true));
            if ( float(VotersYes.length) / MaxVoters() * 100.0 >= VotePercent )
                VotePassed();
            else {
                VHRI.UpdateVoteStatus(self, VHRI.VS_INPROGRESS, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
            }
        }
        else if ( VoteString != "TRYYES" )
            Sender.ClientMessage(strNoVoteInProgress);
    }
    else if ( VoteString == "NO" || VoteString == "TRYNO" ) {
        if ( bVoteInProgress ) {
            if ( Sender.PlayerReplicationInfo.bAdmin ) {
                VoteInfo @= strForcedByAdmin;
                ReplaceText(VoteInfo, "%p", Sender.PlayerReplicationInfo.PlayerName);
                VoteFailed();
                return;
            }
            else if ( VotedTeam != none ) {
                if ( VotedTeam != Sender.PlayerReplicationInfo.Team ) {
                    if ( VoteString != "TRYNO" )
                        Sender.ClientMessage(strOtherTeamVote);
                    return;
                }
                else if ( VotedTeam.TeamIndex < 2 && TeamCaptains[VotedTeam.TeamIndex] == Sender ) {
                    VoteInfo @= strForcedByAdmin;
                    ReplaceText(VoteInfo, "%p", Sender.PlayerReplicationInfo.PlayerName);
                    VoteFailed();
                    return;
                }
            }

            for ( i = 0; i < VotersYes.length; i++ ) {
                if ( VotersYes[i] == Sender ) {
                    VotersYes.remove(i, 1);
                    break;
                }
            }
            for ( i = 0; i < VotersNo.length; i++ ) {
                if ( VotersNo[i] == Sender ) {
                    Sender.ClientMessage(strAlreadyVoted);
                    return;
                }
            }
            VotersNo[VotersNo.length] = Sender;
            BroadcastMessage(GetVoteStatus(Sender, false));
            if ( float(MaxVoters() - VotersNo.length) / MaxVoters() * 100.0 < VotePercent )
                VoteFailed(); // vote fails when it can't theoretically pass the vote
            else
                VHRI.UpdateVoteStatus(self, VHRI.VS_INPROGRESS, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
        }
        else if ( VoteString != "TRYNO" )
            Sender.ClientMessage(strNoVoteInProgress);
    }
    else if ( bVoteInProgress )
        Sender.ClientMessage(strVoteInProgress);
    else if ( !MayStartVoting(Sender))
        Sender.ClientMessage(strPlayerBlocked);
    else {
        VoteInfo = "";
        VotedPlayer = none;
        VotedTeam = none;

        if ( Divide(VoteString, " ", k, v) ) {
            k = trim(k);
            v = trim(v);
        }
        else {
            k = VoteString;
            v = "";
        }
        // check if first is a group
        VO = GetGroupOptions(k);
        if ( VO != none ) {
            // first word is a group, then second is a key and others - value
            g = k;
            if ( Divide(v, " ", k, v) ) {
                k = trim(k);
                v = trim(v);
            }
            else {
                k = v;
                v = "";
            }

            if ( k == "" || k == "HELP" || k ~= "?" )
                VO.SendGroupHelp(Sender, g);
            else {
                idx = VO.GetGroupVoteIndex(Sender, g, k, v, VoteInfo);
                switch (idx) {
                    case VO.VOTE_UNKNOWN:
                        Sender.ClientMessage(strVoteIllegal);
                        VO.SendGroupHelp(Sender, g);
                        break;
                    case VO.VOTE_ILLEGAL:
                        Sender.ClientMessage(strVoteIllegal);
                        break;
                    case VO.VOTE_NOEFECT:
                        Sender.ClientMessage(strVoteHasNoEffect);
                        break;
                    case VO.VOTE_LOCAL:
                        return;
                    default:
                        CurrentVotingObject = VO;
                        VoteIndex = idx;
                        VoteValue = v;
                        if ( VoteInfo == "" )
                            VoteInfo = g @ k @ v;
                        StartVoting(Sender);
                }
            }
        }
        else {
            // no group found - do global vote check
            for ( i = 0; i < VotingOptions.length; ++i ) {
                if ( VotingOptions[i] == none || !VotingOptions[i].bAcceptsGlobalVotes )
                    continue;

                VO = VotingOptions[i];
                idx = VO.GetVoteIndex(Sender, k, v, VoteInfo);
                if ( idx != VO.VOTE_UNKNOWN ) {
                    switch (idx) {
                        case VO.VOTE_ILLEGAL:
                            Sender.ClientMessage(strVoteIllegal);
                            break;
                        case VO.VOTE_NOEFECT:
                            Sender.ClientMessage(strVoteHasNoEffect);
                            break;
                        case VO.VOTE_LOCAL:
                            return;
                        default:
                            CurrentVotingObject = VO;
                            VoteIndex = idx;
                            VoteValue = v;
                            if ( VoteInfo == "" )
                                VoteInfo = k @ v;
                            StartVoting(Sender);
                    }
                    return;
                }
            }
            if ( VO != none && idx == VO.VOTE_UNKNOWN ) {
                Sender.ClientMessage(strVoteUnknown);
            }
        }
    }
}

function bool MayStartVoting(PlayerController Sender)
{
    local int i;

    if ( Sender.PlayerReplicationInfo == none )
        return false;
    // admins can always vote
    if ( Sender.PlayerReplicationInfo.bAdmin )
        return true;
    // spectators can't vote
    if ( Sender.PlayerReplicationInfo.bOnlySpectator )
        return false;

    if ( Level.Game.NumPlayers == 1 )
        return true;

    if ( Sender == FailedVoter && Level.TimeSeconds < FailedVoterBlockTime )
        return false;

    for ( i=0; i<BlockedVoters.length; ++i ) {
        if ( BlockedVoters[i] == Sender)
            return false;
    }

    return true;
}

function BroadcastMessage(string msg)
{
    local Controller P;
    local PlayerController Player;

    for ( P = Level.ControllerList; P != none; P = P.nextController ) {
        Player = PlayerController(P);
        if ( Player != none ) {
            Player.ClientMessage(msg);
        }
    }
}

function StartVoting(PlayerController Initiator)
{
    local string msg;

    if ( Initiator == none || Initiator.PlayerReplicationInfo == none )
        return;

    VoteInitiator = Initiator;
    bVotedPlayer = VotedPlayer != none;
    VotersYes.Length = 1;
    VotersYes[0] = Initiator;
    VotersNo.Length = 0;
    bVoteInProgress = true;
    VoteID++;

    if ( Level.NetMode == NM_Standalone || Initiator.PlayerReplicationInfo.bAdmin ) {
        VotePassed(Initiator.PlayerReplicationInfo.PlayerName);
    }
    else if ( MaxVoters() == 1 && !Initiator.PlayerReplicationInfo.bOnlySpectator ) {
        VotePassed();
    }
    else if ( VotedTeam != none && VotedTeam.TeamIndex < 2 && TeamCaptains[VotedTeam.TeamIndex] == Initiator ) {
        VotePassed(Initiator.PlayerReplicationInfo.PlayerName);
    }
    else {
        msg = strVoteInitiated;
        ReplaceText(msg, "%p", Initiator.PlayerReplicationInfo.PlayerName);
        ReplaceText(msg, "%v", VoteInfo);
        BroadcastMessage(chr(27)$chr(200)$chr(200)$chr(1)$msg);
        VHRI.UpdateVoteStatus(self, VHRI.VS_INPROGRESS, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
        VoteSecondsLeft = VoteCountDown;
        SetTimer(1, true);
    }
}

function Timer()
{
    if ( VoteInitiator == none ) {
        EndVoting();
        BroadcastMessage(chr(27)$chr(200)$chr(1)$chr(1)$strVoteFailedInitiator);
        VHRI.UpdateVoteStatus(self, VHRI.VS_FAILED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
    }
    else if ( bVotedPlayer && (VotedPlayer == none || VotedPlayer.PlayerReplicationInfo == none) ) {
        EndVoting();
        BroadcastMessage(chr(27)$chr(200)$chr(1)$chr(1)$strVoteFailedPlayer);
        VHRI.UpdateVoteStatus(self, VHRI.VS_FAILED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
    }
    else if ( --VoteSecondsLeft <= 0 ) {
        if ( float(VotersYes.length) / MaxVoters() * 100.0 >= VotePercentCountDown ) {
            VotePassed(strTimeout);
        }
        else {
            EndVoting();
            BroadcastMessage(strVoteTimeout);
            VHRI.UpdateVoteStatus(self, VHRI.VS_FAILED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
        }
    }
}


function EndVoting()
{
    bVoteInProgress = false;
    SetTimer(0, false);
}

function VotePassed(optional String ForcedByPlayerName)
{
    local string msg;

    if ( !bVoteInProgress )
        return;

    EndVoting();

    if ( VoteInitiator == none ) {
        BroadcastMessage(chr(27)$chr(200)$chr(1)$chr(1)$strVoteFailedInitiator);
        VHRI.UpdateVoteStatus(self, VHRI.VS_FAILED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
        return;
    }

    CurrentVotingObject.ApplyVoteValue(VoteIndex, VoteValue);
    msg = strVotePassed;
    ReplaceText(msg, "%v", VoteInfo);
    if ( ForcedByPlayerName != "" ) {
        msg @=  strForcedByAdmin;
        ReplaceText(msg, "%p", ForcedByPlayerName);
    }
    BroadcastMessage(chr(27)$chr(1)$chr(200)$chr(1)$msg);
    VHRI.UpdateVoteStatus(self, VHRI.VS_PASSED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
}

function VoteFailed()
{
    if ( VoteCoolDown > 0 ) {
        FailedVoter = VoteInitiator;
        FailedVoterBlockTime = Level.TimeSeconds + VoteCoolDown;
    }
    EndVoting();
    BroadcastMessage(chr(27)$chr(200)$chr(1)$chr(1)$strVoteFailed);
    VHRI.UpdateVoteStatus(self, VHRI.VS_FAILED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
}

static function string ParseHelpLine(string s)
{
    ReplaceText(s, "%r", chr(27)$chr(200)$chr(1)$chr(1));
    ReplaceText(s, "%g", chr(27)$chr(1)$chr(200)$chr(1));
    ReplaceText(s, "%b", chr(27)$chr(1)$chr(100)$chr(200));
    ReplaceText(s, "%w", chr(27)$chr(200)$chr(200)$chr(200));
    ReplaceText(s, "%y", chr(27)$chr(200)$chr(200)$chr(1));
    ReplaceText(s, "%p", chr(27)$chr(200)$chr(1)$chr(200));
    ReplaceText(s, "%k", chr(27)$chr(64)$chr(64)$chr(64));
    return s;
}

function PrepareHelp()
{
    local int i, j, l;
    local ScrnVotingOptions VO;

    bHelpPrepared = true;

    l = HelpInfo.length;
    // add help infos from voting options
    for ( j=0; j < VotingOptions.length; ++j ) {
        VO = VotingOptions[j];
        if ( VO != none) {
            HelpInfo.insert(l, VO.HelpInfo.length);
            for ( i = 0; i < VO.HelpInfo.length; ++i) {
                HelpInfo[l++] = VO.HelpInfo[i];
            }
        }
    }

    for ( i = 0; i < l; ++i) {
        HelpInfo[i] = ParseHelpLine(HelpInfo[i]);
    }
}

function SendHelp(PlayerController Sender)
{
    local int i;

    if ( !bHelpPrepared )
        PrepareHelp();

    for ( i = 0; i < HelpInfo.length; ++i)
        Sender.ClientMessage(HelpInfo[i]);
}

simulated function PostBeginPlay()
{
    if ( Level.NetMode == NM_Client ) {
        log("Voting Handler should be used only on the server side", class.outer.name);
        Destroy();
        return;
    }

    VHRI = Spawn(VHReplicationInfoClass, self);
    VHRI.mutRef = Self;
}

function ServerTraveling(string URL, bool bItems)
{
    if (NextMutator != None)
        NextMutator.ServerTraveling(URL,bItems);

    if ( VHRI != none ) {
        VHRI.Destroy();
        VHRI = none;
    }
}

//returns true, if specifield vote is in progress
//pass -1 to VIndex to check all votes from specified ScrnVotingOptions object
function bool IsMyVotingRunning(ScrnVotingOptions VO, int VIndex)
{
    return bVoteInProgress && CurrentVotingObject == VO && (VoteIndex == VIndex || VIndex == -1);
}


defaultproperties
{
    VoteCountDown=70
    VotePercent=51.000
    VotePercentCountDown=51.00
    VoteCoolDown=10

    strVersion="ScrN Voting Handler v%m.%n"

    strVoteInitiated="%p initiated a vote: %v."
    strVotePassed="Vote passed: %v"
    strVoteFailed="Vote failed"
    strVoteFailedInitiator="Vote failed due to initiator's disconnect"
    strVoteFailedPlayer="Vote failed due to player's disconnect"
    strVoteTimeout="Vote failed due to timeout"
    strVoteInProgress="Another vote in progress"
    strNoVoteInProgress="No vote in progress"
    strAlreadyVoted="You've already voted"
    strVoteUnknown="Unknown vote"
    strVoteIllegal="Illegal vote arguments"
    strVoteHasNoEffect="Vote has no effect"
    strForcedByAdmin="(forced by %p)"
    strVotedYes="%p voted YES on: %v (+%y -%n)"
    strVotedNo="%p voted NO on: %v (+%y -%n)"
    strVoteStatus="Current vote: %v (+%y -%n)"
    strSpectatorsCantVote="Spectators can not vote!"
    strOtherTeamVote="Can't participate in other team's voting!"
    strTimeout="TIMEOUT"
    strPlayerBlocked="You are disallowed to start a voting"

    HelpInfo(0)="%bVoting Options:"
    HelpInfo(1)="%gHELP %w Show this information"
    HelpInfo(2)="%gYES%w|%gNO %w Accept|Decline current vote"
    HelpInfo(3)="%gSTATUS %w Show status of the current vote"

    GroupName="SCRN-VOTE"
    FriendlyName="ScrN Voting Handler"
    Description="Allows voting via MUTATE VOTE console command"

    bAddToServerPackages=true

    VHReplicationInfoClass=class'ScrnVotingHandlerV4.VHReplicationInfo'
}
