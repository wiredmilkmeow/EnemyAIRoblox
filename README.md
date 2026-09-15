This is a full NPC system

It is primarily meant to use a state machine like framework when designing NPC's


Once running you tag a rig in studio with "EnemyAI" and give it 2 attributes for needed info:

EnemyType : string/name of the state machine module you intend to use

PathingType : string/name of the pathfinding algorithm you intend to use


Everything will be automaticly cleaned up on the tagged instance once the tag is removed

The system is sever side for the Roblox Engine, It is was not designed with the intention of handling hundreds of NPC instances at once.
This system was intended to work for a linear horror game with at most 15-20 Instances running at the same time.

Lastly this has not fully been debuged and currently there are a few type checking and module fetching/sharing issues that need to be fixed. This is mainly intended for portfolio use.