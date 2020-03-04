---
name: 'ecs-notes'
type: 'blog'
title: 'Why ECS'
author: 'xorkevin'
date: 2020-03-02T14:01:18-08:00
description: 'Why do we need entity component system'
tags: ['gamedev', 'notes']
projecturl: ''
draft: true
---

I, like many programmers often do, first began experimenting with programming
through games. They can be quite simple to write, and provide a self contained,
easily testable, tangible, and fun way to learn programming. To this day, the
first thing I will try to build when learning a new UI framework or platform is
to build a simple clicker "game". Though highly contrived, it exercises
maintaining and updating state, programmatically updating the view, and
interfacing with the event system---all common requirements for building a UI
program.

My early experimentation with game programming quickly reached an impasse,
however. I discovered, in attempting to write more complex games, that my game
logic always became tangled, difficult to understand, and difficult to debug.
It wasn't until recently, in having to design and implement a game for a class
project, that I learned the reason why. Now, with many more additional years of
experience, I understand that game architecture is an entirely different beast
compared with the "traditional" object oriented approach to program design.

Game architecture has a wildly different philosophy than more conventional
programs, driven by the unique way data is organized and accessed within them.
Currently, the most widely accepted solution is to use the entity component
system pattern, or some variant of it. Learning about how the current best
architectural patterns solve these problems that uniquely appear in game
programming has been useful for me to compare against architectural patterns in
other domains. These comparisons give insight into the key aspects of a
particular problem that motivate a certain type of solution.

## The Problem

To reiterate, using "traditional" object oriented designs for game development
is not recommended, because it quickly leads to tangled logic and difficult to
debug code. To better visualize this, let us consider a contrived example.

Say there is a roguelike[^roguelike] dungeon crawler game with the following
types of objects and their corresponding behaviors:

- player: is collidable, has position, has velocity, has health, is
  controllable, and is renderable
- enemy: is collidable, has position, has velocity, has health, and is
  renderable
- trap: has position, has health, and is renderable
- wall: is collidable, has position, and is renderable

The objective here is to write maintainable implementations for these behaviors
that allows us to easily share those implementations amongst the multiple types
of objects that require them, and allow behaviors to be easily added and
modified.

[^roguelike]: Roguelike game {{<core/anchor href="https://en.wikipedia.org/wiki/Roguelike" ext="1" />}}

A traditional object oriented approach here would dictate that we should
abstract over the behaviors of each type of object. Inheritance is one such
solution to share implementation across multiple types of objects, though it
would be difficult to implement in practice here, because certain object types
share some behaviors in a nonhierarchical manner. For example, player, enemy,
and wall share collision, position, and renderable; and player and enemy share
velocity and health. However, player, enemy, and trap share position, health
and renderable as well. There is no object type hierarchy here where supertypes
may have behavior that is shared only by subtypes. Thus inheritance is a poor
solution for this problem.

Alternately, interfaces are another traditional objected oriented solution.
Addressing the previously stated issues, object types only have to implement
the behavior that they require. For example, the player type could implement
the collidable interface by delegating it to a common shared collidable
implementation, and likewise for the rest of the player's behaviors. Other
object types could similarly implement only the interfaces that they require.
However, the issue with this approach is that business logic for games often
concerns not just one entire object at a time, but only parts of all objects at
a time. For example, in order to calculate collision, one needs to consider the
collision and position properties of all objects, but may not care about
whether an object has health or is renderable.

Furthermore, both of these approaches fail at a more fundamental level.
Abstracting over behaviors on a per object basis is less useful for this
problem, because the "behaviors" in question are mostly direct data access and
mutation. For example, the position interface would most likely just consist of
`get_pos() -> Vec` and `set_pos(pos: Vec)`, because it needs to be queried and
updated in unique ways by velocity and collision. Similarly, the health
interface would most likely only consist of `get_health() -> int` and
`change_health(delta: int)` to support taking damage in various ways such as
being attacked by an enemy, or receiving damage over time from a trap.

Abstracting over behaviors is most powerful when the behaviors are complex and
higher level, so that the complexity of lower level implementation details is
hidden from those who depend on the interface. Interfaces that directly expose
low level implementation are inherently weaker.

## Enter Entity Component System

---

so the super efficient way to solve all these issues is to use an
entity-component-system framework

typically abbreviated as ecs

an entity is just an id, (think of it like a global identifier for a "thing",
like you would a userid in a db)

a component is a property of an entity. (so a velocity component might be one,
as would a position component)

these components are all grouped together in a single data structure, typically
an array for fast processing

so instead of a traditional oop mindset, where a player object might own its
velocity, position, etc.

now there is a component manager for each type of component, say for example, a
velocity component manager which goes, i have this array of components, each of
which correspond to particular entities (ids)

grouping like components together in this way paves the way for the final part
of ecs, system

an ecs instance (known as a world) may have many systems running every tick

you may have a movement sytem which checks for input, and updates the velocity
component of a player

you may also have a physics system which iterates through all the velocity and
position components, and updates the position based on velocity for the time
step

or you may have a collision component which iterates through all collidable,
velocity, and position components, and ensures that colliding objects don't
intersect

ecs just becomes this wonderful pattern where you define this large segmented
pool of state (your components), and then you can separately define your
business logic which operates on those components (your systems)

all your systems care about are the components that they are responsible for

so now going back to the beginning

let's say i want to add a car to my world that has a velocity and a position,
is collidable, and is renderable

all i have to do is create a new entity, with the proper velocity, position,
collision, and render parameters

and all the systems that care about those components will automatically begin
to operate on those components, like updating position based on velocity, or
updating velocity based on collision, or determing what to draw to the screen
at a particular position
