class ScrnVotingHandlerMut extends ScrnMutator
    Config(ScrnVoting);

var globalconfig int VoteCountDown;
var globalconfig float VotePercent, VotePercentCountDown;

var protected bool bVoteInProgress;
var protected int VoteSecondsLeft;
var protected array <PlayerController> VotersYes, VotersNo;

var class<ScrnVotingMsg> Msg;

var string VoteInfo; // user-friendly information about current vore
var protected int VoteIndex;
var protected string VoteValue; // value to be set, if vote passes
var protected string VoteCommand;
var protected ScrnVotingOptions CurrentVotingObject; //objects that controls current vote value
var transient PlayerController VoteInitiator;
var transient TeamInfo VotedTeam;
var PlayerController TeamCaptains[2];
var transient PlayerController VotedPlayer;
var protected transient bool bVotedPlayer; // if true, VotedPlayer is used in the current vote
var transient bool bVotedPlayerAutoVote; // ScrnVotingOptions may set it during GetVoteIndex() to make VotedPlayer to autovote YES

var protected array<ScrnVotingOptions> VotingOptions;

var array <string> HelpInfo;
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


function Mutate(string MutateString, PlayerController Sender)
{
    if ( MutateString ~= "vote" )
        Vote("", Sender);
    else if ( left(MutateString, 5) ~= "vote " )
        Vote(Right(MutateString, len(MutateString)-5), Sender);
    else {
        super.Mutate(MutateString, Sender);
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

    if (bVoteInProgress && VoteString == VoteCommand) {
        // merge duplicate votes
        VoteString = "YES";
    }

    if ( VoteString == "" || VoteString == "HELP" || VoteString ~= "INFO"  || VoteString ~= "?") {
        SendHelp(Sender);
    }
    else if ( VoteString == "STATUS" ) {
        if (!bVoteInProgress) {
            SendMsg(Sender, Msg.default.msgNoVoteInProgress);
        }
        else {
            Sender.ClientMessage(VoteInfo);
            SendMsg(Sender, Msg.default.msgVoteStatus);
        }
    }
    else if (Sender.PlayerReplicationInfo.bOnlySpectator && !class'ScrnF'.static.IsAdmin(Sender)) {
        SendMsg(Sender, Msg.default.msgSpectatorsCantVote);
    }
    else if ( VoteString == "YES" || VoteString == "TRYYES" ) {
        if ( bVoteInProgress ) {
            if ( Sender.PlayerReplicationInfo.bAdmin ) {
                VotePassed(Sender.PlayerReplicationInfo);
                return;
            }
            else if ( VotedTeam != none ) {
                if ( VotedTeam != Sender.PlayerReplicationInfo.Team ) {
                    if (VoteString != "TRYYES") {
                        SendMsg(Sender, Msg.default.msgOtherTeamVote);
                    }
                    return;
                }
                else if ( VotedTeam.TeamIndex < 2 && TeamCaptains[VotedTeam.TeamIndex] == Sender ) {
                    VotePassed(Sender.PlayerReplicationInfo);
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
                    SendMsg(Sender, Msg.default.msgAlreadyVoted);
                    return;
                }
            }
            VotersYes[VotersYes.length] = Sender;
            BroadcastMsg(Msg.default.msgVotedYes, Sender.PlayerReplicationInfo);
            if ( float(VotersYes.length) / MaxVoters() * 100.0 >= VotePercent )
                VotePassed();
            else {
                VHRI.UpdateVoteStatus(self, VHRI.VS_INPROGRESS, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
            }
        }
        else if ( VoteString != "TRYYES" ) {
            SendMsg(Sender, Msg.default.msgNoVoteInProgress);
        }
    }
    else if ( VoteString == "NO" || VoteString == "TRYNO" ) {
        if ( bVoteInProgress ) {
            if ( Sender.PlayerReplicationInfo.bAdmin ) {
                VoteFailed(Sender.PlayerReplicationInfo);
                return;
            }
            else if ( VotedTeam != none ) {
                if ( VotedTeam != Sender.PlayerReplicationInfo.Team ) {
                    if (VoteString != "TRYNO") {
                        SendMsg(Sender, Msg.default.msgOtherTeamVote);
                    }
                    return;
                }
                else if ( VotedTeam.TeamIndex < 2 && TeamCaptains[VotedTeam.TeamIndex] == Sender ) {
                    VoteFailed(Sender.PlayerReplicationInfo);
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
                    SendMsg(Sender, Msg.default.msgAlreadyVoted);
                    return;
                }
            }
            VotersNo[VotersNo.length] = Sender;
            BroadcastMsg(Msg.default.msgVotedNo, Sender.PlayerReplicationInfo);
            if ( float(MaxVoters() - VotersNo.length) / MaxVoters() * 100.0 < VotePercent )
                VoteFailed(); // vote fails when it can't theoretically pass the vote
            else
                VHRI.UpdateVoteStatus(self, VHRI.VS_INPROGRESS, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
        }
        else if (VoteString != "TRYNO") {
            SendMsg(Sender, Msg.default.msgNoVoteInProgress);
        }
    }
    else if ( bVoteInProgress ) {
        SendMsg(Sender, Msg.default.msgVoteInProgress);
    }
    else if ( !MayStartVoting(Sender)) {
        SendMsg(Sender, Msg.default.msgPlayerBlocked);
    }
    else {
        VoteInfo = "";
        VotedPlayer = none;
        VotedTeam = none;
        bVotedPlayerAutoVote = false;

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
                        SendMsg(Sender, Msg.default.msgVoteUnknown);
                        VO.SendGroupHelp(Sender, g);
                        break;
                    case VO.VOTE_ILLEGAL:
                        SendMsg(Sender, Msg.default.msgVoteIllegal);
                        break;
                    case VO.VOTE_NOEFECT:
                        SendMsg(Sender, Msg.default.msgVoteHasNoEffect);
                        break;
                    case VO.VOTE_LOCAL:
                        return;
                    default:
                        CurrentVotingObject = VO;
                        VoteIndex = idx;
                        VoteValue = v;
                        if ( VoteInfo == "" )
                            VoteInfo = g @ k @ v;
                        VoteCommand = VoteString;
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
                            SendMsg(Sender, Msg.default.msgVoteIllegal);
                            break;
                        case VO.VOTE_NOEFECT:
                            SendMsg(Sender, Msg.default.msgVoteHasNoEffect);
                            break;
                        case VO.VOTE_LOCAL:
                            return;
                        default:
                            CurrentVotingObject = VO;
                            VoteIndex = idx;
                            VoteValue = v;
                            if ( VoteInfo == "" )
                                VoteInfo = k @ v;
                            VoteCommand = VoteString;
                            StartVoting(Sender);
                    }
                    return;
                }
            }
            if ( VO != none && idx == VO.VOTE_UNKNOWN ) {
                SendMsg(Sender, Msg.default.msgVoteUnknown);
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

    msg = class'scrnF'.static.ParseColorTags(msg);

    for ( P = Level.ControllerList; P != none; P = P.nextController ) {
        if (!P.bIsPlayer) continue;
        Player = PlayerController(P);
        if ( Player != none ) {
            Player.ClientMessage(msg);
        }
    }
}

function bool CheckMsg(out int msgID)
{
    if (msgID > 0xFFFF) {
        warn("Bad voting message id: " $ msgID);
        return false;
    }
    if (bVoteInProgress) {
        msgID = msgID | (min(255, VotersYes.length) << 16);
        msgID = msgID | (min(255, VotersNo.length) << 24);
    }
    return true;
}

function BroadcastMsg(int msgID, optional PlayerReplicationInfo VotedPRI)
{
    if (!CheckMsg(msgID))
        return;

    Level.Game.BroadcastLocalizedMessage(Msg, msgID, VotedPRI);
}

function SendMsg(PlayerController Player, int msgID, optional PlayerReplicationInfo VotedPRI)
{
    if (!CheckMsg(msgID))
        return;

    Player.ReceiveLocalizedMessage(Msg, msgID, VotedPRI);
}

function StartVoting(PlayerController Initiator)
{
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
        VotePassed(Initiator.PlayerReplicationInfo);
    }
    else if ( MaxVoters() == 1 && !Initiator.PlayerReplicationInfo.bOnlySpectator ) {
        VotePassed();
    }
    else if ( VotedTeam != none && VotedTeam.TeamIndex < 2 && TeamCaptains[VotedTeam.TeamIndex] == Initiator ) {
        VotePassed(Initiator.PlayerReplicationInfo);
    }
    else {
        BroadcastMsg(Msg.default.msgVoteInitiated, Initiator.PlayerReplicationInfo);
        BroadcastMessage("^y$" $ VoteInfo);
        VHRI.UpdateVoteStatus(self, VHRI.VS_INPROGRESS, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
        VoteSecondsLeft = VoteCountDown;
        SetTimer(1, true);
        if (bVotedPlayerAutoVote && bVotedPlayer) {
            Vote("YES", VotedPlayer);
        }
    }
}

function Timer()
{
    if ( VoteInitiator == none ) {
        VoteFailed(none, Msg.default.msgVoteFailedInitiator);
    }
    else if ( bVotedPlayer && (VotedPlayer == none || VotedPlayer.PlayerReplicationInfo == none) ) {
        VoteFailed(none, Msg.default.msgVoteFailedPlayer);
    }
    else if ( --VoteSecondsLeft <= 0 ) {
        if ( float(VotersYes.length) / MaxVoters() * 100.0 >= VotePercentCountDown ) {
            VotePassed(none, Msg.default.msgVotePassedTimeout);
        }
        else {
            VoteFailed(none, Msg.default.msgVoteFailedTimeout);
        }
    }
    else if ( float(VotersYes.length) / MaxVoters() * 100.0 >= VotePercent ) {
        VotePassed();
    }
}

function EndVoting()
{
    bVoteInProgress = false;
    SetTimer(0, false);
}

function VotePassed(optional PlayerReplicationInfo ForcedPRI, optional int customMsgID)
{
    local int msgID;

    if (!bVoteInProgress)
        return;

    if (VoteInitiator == none) {
        VoteFailed(none, Msg.default.msgVoteFailedInitiator);
        return;
    }

    EndVoting();
    CurrentVotingObject.ApplyVoteValue(VoteIndex, VoteValue);

    if (ForcedPRI != none) {
        msgID = Msg.default.msgPassedByAdmin;
    }
    else if (customMsgID != 0) {
        msgID = customMsgID;
    }
    else {
        msgID = Msg.default.msgVotePassed;
    }
    BroadcastMsg(msgID, ForcedPRI);
    BroadcastMessage("^g$" $ VoteInfo);

    if ( VHRI != none )
        VHRI.UpdateVoteStatus(self, VHRI.VS_PASSED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
}

function VoteFailed(optional PlayerReplicationInfo ForcedPRI, optional int customMsgID)
{
    local int msgID;

    if (VoteCoolDown > 0 && VoteInitiator != none && customMsgID != 0) {
        FailedVoter = VoteInitiator;
        FailedVoterBlockTime = Level.TimeSeconds + VoteCoolDown;
    }

    EndVoting();

    if (ForcedPRI != none) {
        msgID = Msg.default.msgFailedByAdmin;
    }
    else if (customMsgID != 0) {
        msgID = customMsgID;
    }
    else {
        msgID = Msg.default.msgVoteFailed;
    }
    BroadcastMsg(Msg.default.msgVoteFailed, ForcedPRI);

    if ( VHRI != none )
        VHRI.UpdateVoteStatus(self, VHRI.VS_FAILED, VoteInfo, VotersYes.length, VotersNo.length, VoteID);
}

static function string ParseHelpLine(string s)
{
    // legacy color tags
    s = Repl(s, "%r", chr(27)$chr(200)$chr(1)$chr(1), true);
    s = Repl(s, "%g", chr(27)$chr(1)$chr(200)$chr(1), true);
    s = Repl(s, "%b", chr(27)$chr(1)$chr(100)$chr(200), true);
    s = Repl(s, "%w", chr(27)$chr(200)$chr(200)$chr(200), true);
    s = Repl(s, "%y", chr(27)$chr(200)$chr(200)$chr(1), true);
    s = Repl(s, "%p", chr(27)$chr(200)$chr(1)$chr(200), true);
    s = Repl(s, "%k", chr(27)$chr(64)$chr(64)$chr(64), true);
    // standard color tags
    return class'ScrnF'.static.ParseColorTags(s);
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
    VersionNumber=97107

    VoteCountDown=30
    VotePercent=51.000
    VotePercentCountDown=49.00
    VoteCoolDown=10

    Msg=class'ScrnVotingMsg'

    HelpInfo(0)="%bVoting Options:"
    HelpInfo(1)="%gHELP %w Show this information"
    HelpInfo(2)="%gYES%w|%gNO %w Accept|Decline current vote"
    HelpInfo(3)="%gSTATUS %w Show status of the current vote"

    GroupName="SCRN-VOTE"
    FriendlyName="ScrN Voting Handler"
    Description="Allows voting via MUTATE VOTE console command"

    bAddToServerPackages=true

    VHReplicationInfoClass=class'ScrnVotingHandler.VHReplicationInfo'
}
