class VHReplicationInfo extends ReplicationInfo;

var ScrnVotingHandlerMut mutRef;

var class<VHInteraction> InteractionClass;
var VHInteraction myInteraction;

var String VoteName;
var int YesVotes, NoVotes;
var int VoteStatus, OldVoteStatus;
var byte VoteID; // ID ensures that data will be replicated to clients in cases when 2 same rows are passed in a row
const VS_INACTIVE = 0;
const VS_INPROGRESS = 1;
const VS_PASSED = 2;
const VS_FAILED = 3;

replication {
    reliable if ( Role == ROLE_Authority )
        VoteID, VoteStatus, YesVotes, NoVotes, VoteName;
}

simulated function PostNetReceive()
{
    if ( Level.NetMode != NM_DedicatedServer && VoteStatus != VS_INACTIVE ) {
        if ( myInteraction == none )
            SpawnInteraction();

        if ( myInteraction == none ) {
            log("Unable to spawn Voting Interaction", class.outer.name);
            return;
        }

        myInteraction.VoteName = VoteName; //just to be sure
        if ( VoteStatus == VS_INPROGRESS ) {
            if ( OldVoteStatus != VS_INPROGRESS) {
                myInteraction.VoteStarted(VoteName);
            }
            myInteraction.UpdateVotes(YesVotes, NoVotes);
        }
        else {
            myInteraction.VoteEnded(VoteStatus == VS_PASSED);
        }
        OldVoteStatus = VoteStatus;
    }
}

simulated function PreBeginPlay()
{
    local VHInteraction RemoveMe;

    super.PreBeginPlay();

    // remove interaction left from previous map
    foreach AllObjects(class'VHInteraction', RemoveMe) {
        RemoveMe.Master.RemoveInteraction(RemoveMe);
    }
}

function UpdateVoteStatus(Actor Updater, int Status, String VoteName, int YesVotes, int NoVotes, byte VoteID)
{
    self.VoteStatus = Status;
    self.VoteName = VoteName;
    self.YesVotes = YesVotes;
    self.NoVotes = NoVotes;
    self.VoteID = VoteID;
    NetUpdateTime = Level.TimeSeconds - 1;
    if ( Level.GetLocalPlayerController() != none )
        PostNetReceive(); // solo mode or listen servers

    if ( VoteStatus == VS_PASSED || VoteStatus == VS_FAILED ) {
        SetTimer(1, false); // bug fix when late joiners received status of already ended vote
    }
}

function Timer()
{
    VoteStatus = VS_INACTIVE;
}


simulated function SpawnInteraction()
{
    local PlayerController PC;

    if ( myInteraction != none )
        return;

    PC = Level.GetLocalPlayerController();
    if (PC != None ) {
        myInteraction = VHInteraction(PC.Player.InteractionMaster.AddInteraction(String(InteractionClass),PC.Player));
    }
}

simulated function Destroyed()
{
    super.Destroyed();

    if ( myInteraction != none )
        myInteraction.Master.RemoveInteraction(myInteraction);
}

defaultproperties
{
    InteractionClass=class'ScrnVotingHandlerV4.VHInteraction'
    bNetNotify=true
    bAlwaysRelevant=true
    bOnlyRelevantToOwner=False
}