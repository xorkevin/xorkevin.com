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
first thing I will try to build when learning a new new UI framework or
platform is to build a simple clicker "game". Though highly contrived, it
exercises maintaining and updating state, programmatically updating the view,
and interfacing with the event system.

My early experimentation with game programming quickly reached an impasse,
however. I discovered, in attempting to write more complex games, that my game
logic always became tangled, difficult to understand, and difficult to debug.
It wasn't until recently, in having to design and implement a game for a class
project, that I learned the reason why. Backed by my, now, many more additional
years of experience since I began learning to program, I now understand that
game architecture is an entirely different beast compared with the traditional
and naive object oriented approach to program design.

Game architecture has a wildly different philosophy than more conventional
programs, driven by the unique way data is organized and accessed for games.
Learning about how the current best architectural patterns solve these unique
problems that appear in game programming has been useful for me to compare
against architectural patterns in other domains. These comparisons give insight
into the key aspects of a particular problem that motivate a certain type of
solution.

## Enter Entity Component System

To reiterate, using "traditional" objected oriented for game development is
highly unconventional, because it quickly leads to tangled logic and difficult
to understand and debug code.

---

like say a player is collidable, has velocity, has position, and is renderable,
a wall is collidable, has position, and is renderable, and a car spawner has
position and has a timer for how often a car is spawned

the objective here is to share implementation as much as possible

because it would suck to have to copy and paste code over and over again

inheritance wouldn't be good, because these things have properties that are
shared by some groups, but not by others

so it's not necessarily tree like

implementing interfaces would be nice

say you had a player object, that could compose over a collidable
implementation and delegate the collidable methods to that, and so on for
velocity, position, renderable, etc.

but now the issue is, what if you wanted to grab all objects with velocity to
update their position for this time step

that would be difficult to do

likewise, when you want to calculate what collides with what, you need to grab
all collidable things. there's really no good way to organize all these objects
so you can grab all the ones that are collidable

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
