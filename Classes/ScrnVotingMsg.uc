// Generic localized messages
class ScrnVotingMsg extends LocalMessage
    abstract;


var const int msgVoteInitiated;
var const int msgVotePassed;
var const int msgPassedByAdmin;
var const int msgVotePassedTimeout;
var const int msgVoteFailed;
var const int msgFailedByAdmin;
var const int msgVoteFailedTimeout;
var const int msgVoteFailedInitiator;
var const int msgVoteFailedPlayer;
var const int msgVoteInProgress;
var const int msgNoVoteInProgress;
var const int msgAlreadyVoted;
var const int msgVoteUnknown;
var const int msgVoteIllegal;
var const int msgVoteHasNoEffect;
var const int msgVotedYes;
var const int msgVotedNo;
var const int msgVoteStatus;
var const int msgSpectatorsCantVote;
var const int msgOtherTeamVote;
var const int msgPlayerBlocked;

var const localized string strVoteInitiated;
var const localized string strVotePassed;
var const localized string strPassedByAdmin;
var const localized string strVotePassedTimeout;
var const localized string strVoteFailed;
var const localized string strFailedByAdmin;
var const localized string strVoteFailedTimeout;
var const localized string strVoteFailedInitiator;
var const localized string strVoteFailedPlayer;
var const localized string strVoteInProgress;
var const localized string strNoVoteInProgress;
var const localized string strAlreadyVoted;
var const localized string strVoteUnknown;
var const localized string strVoteIllegal;
var const localized string strVoteHasNoEffect;
var const localized string strVotedYes;
var const localized string strVotedNo;
var const localized string strVoteStatus;
var const localized string strSpectatorsCantVote;
var const localized string strOtherTeamVote;
var const localized string strPlayerBlocked;

static function string GetString(
        optional int msgID,
        optional PlayerReplicationInfo RelatedPRI_1,
        optional PlayerReplicationInfo RelatedPRI_2,
        optional Object OptionalObject
    )
{
    local string s;
    local int y, n;

    y = (msgID >>> 16) & 0xFF;
    n = (msgID >>> 24) & 0xFF;
    msgID = msgID & 0xFFFF;

    switch (msgID) {
        case default.msgVoteInitiated: s = default.strVoteInitiated; break;
        case default.msgVotePassed: s = default.strVotePassed; break;
        case default.msgPassedByAdmin: s = default.strPassedByAdmin; break;
        case default.msgVotePassedTimeout: s = default.strVotePassedTimeout; break;
        case default.msgVoteFailed: s = default.strVoteFailed; break;
        case default.msgFailedByAdmin: s = default.strFailedByAdmin; break;
        case default.msgVoteFailedTimeout: s = default.strVoteFailedTimeout; break;
        case default.msgVoteFailedInitiator: s = default.strVoteFailedInitiator; break;
        case default.msgVoteFailedPlayer: s = default.strVoteFailedPlayer; break;
        case default.msgVoteInProgress: s = default.strVoteInProgress; break;
        case default.msgNoVoteInProgress: s = default.strNoVoteInProgress; break;
        case default.msgAlreadyVoted: s = default.strAlreadyVoted; break;
        case default.msgVoteUnknown: s = default.strVoteUnknown; break;
        case default.msgVoteIllegal: s = default.strVoteIllegal; break;
        case default.msgVoteHasNoEffect: s = default.strVoteHasNoEffect; break;
        case default.msgVotedYes: s = default.strVotedYes; break;
        case default.msgVotedNo: s = default.strVotedNo; break;
        case default.msgVoteStatus: s = default.strVoteStatus; break;
        case default.msgSpectatorsCantVote: s = default.strSpectatorsCantVote; break;
        case default.msgOtherTeamVote: s = default.strOtherTeamVote; break;
        case default.msgPlayerBlocked: s = default.strPlayerBlocked; break;
    }

    s = Repl(s, "%y", y, true);
    s = Repl(s, "%n", n, true);
    s = Repl(s, "%p", class'ScrnF'.static.ColoredPlayerName(RelatedPRI_1), true);
    s = Repl(s, "%o", class'ScrnF'.static.ColoredPlayerName(RelatedPRI_2), true);
    return class'ScrnF'.static.ParseColorTags(s);
}

defaultproperties
{
    bIsSpecial=false
    bIsConsoleMessage=true

    msgVoteInitiated=0
    msgVotePassed=1
    msgPassedByAdmin=2
    msgVotePassedTimeout=3
    msgVoteFailed=4
    msgFailedByAdmin=5
    msgVoteFailedTimeout=6
    msgVoteFailedInitiator=7
    msgVoteFailedPlayer=8
    msgVoteInProgress=9
    msgNoVoteInProgress=10
    msgAlreadyVoted=11
    msgVoteUnknown=12
    msgVoteIllegal=13
    msgVoteHasNoEffect=14
    msgVotedYes=15
    msgVotedNo=16
    msgVoteStatus=17
    msgSpectatorsCantVote=18
    msgOtherTeamVote=19
    msgPlayerBlocked=20

    strVoteInitiated="%p ^y$initiated a vote:"
    strVotePassed="^g$Vote passed:"
    strPassedByAdmin="^u$Vote forced by %p^c$:"
    strVotePassedTimeout="^g$Vote passed due to timeout:"
    strVoteFailed="^r$Vote failed"
    strFailedByAdmin="^r$Vote declined by %p"
    strVoteFailedTimeout="^r$Vote failed due to timeout"
    strVoteFailedInitiator="^r$Vote failed due to the initiator's disconnect"
    strVoteFailedPlayer="^r$Vote failed due to the player's disconnect"
    strVoteInProgress="Another vote in progress"
    strNoVoteInProgress="No vote in progress"
    strAlreadyVoted="You've already voted"
    strVoteUnknown="Unknown vote"
    strVoteIllegal="Illegal vote arguments"
    strVoteHasNoEffect="Vote has no effect"
    strVotedYes="%p voted YES (+%y -%n)"
    strVotedNo="%p voted NO (+%y -%n)"
    strVoteStatus="Current votes: (+%y -%n)"
    strSpectatorsCantVote="Spectators can not vote!"
    strOtherTeamVote="Cannot participate in other team's voting!"
    strPlayerBlocked="You are disallowed to start a voting"
}
