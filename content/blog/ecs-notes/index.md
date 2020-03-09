---
name: 'ecs-notes'
type: 'blog'
title: 'Why ECS'
author: 'xorkevin'
date: 2020-03-02T14:01:18-08:00
lastmod: 2020-03-08T23:08:48-07:00
description: 'What is entity component system for'
tags: ['gamedev', 'notes']
projecturl: ''
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

### Inheritance

A traditional object oriented approach here would dictate that we should
abstract over the behaviors for each object type. Inheritance is one such
solution to share implementation across multiple types of objects, though it
would be difficult to implement in practice here, because certain object types
share some behaviors in a nonhierarchical manner. For example, player, enemy,
and wall share collision, position, and renderable; and player and enemy share
velocity and health. However, player, enemy, and trap share position, health,
and renderable as well. There is no object type hierarchy here where supertypes
may have behavior that is shared only by subtypes. Thus inheritance is a poor
solution for this problem.

### Interfaces

Alternately, interfaces are another traditional objected oriented solution.
Addressing the previously stated issues, object types only have to implement
the behavior that they require. For example, the player type could implement
the collidable interface by delegating it to a common, shared collidable
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

Entity component system (ECS) attempts to address the issues that we have seen
above, i.e. a heavy emphasis on data access and mutation, and objects that are
composed of many subcomponents. It has, as its name suggests, three main parts:

- Entity: An entity is conceptually an object that exists in the game world.
  Most importantly, an entity does not contain any data or behavior itself. It
  is represented only by a global identifier (not unlike the primary key of a
  database table). Usually, there exists an "entity manager" which keeps a
  record of all the entities that currently exist.
- Component: A component is a property of an entity, and only stores a
  particular facet of data about an entity, such as a velocity component or
  position component. Importantly, components do not contain any behavior. Like
  entities themselves, components of the same type are usually all stored
  together in a single data structure (typically an array for performance
  reasons) and managed by a "component manager". This is in stark contrast with
  traditional the OOP mindset, where a player object might own its velocity,
  position, etc. In ECS, component managers each own all the components of a
  particular type. For example, a velocity component manager owns and manages
  all the velocity components of all entities in the game world.
- System: Grouping like components together through component managers paves
  the way for the final part of ECS, system. A system contains an aspect of the
  business logic of a game. An ECS instance (known as a world) may have many
  systems running every tick. Systems operate on specific subsets of
  components, read their state, and act upon it, which may include updating the
  component, updating other components, or dispatching events. For example, a
  physics system may iterate through all entities with velocity and position
  components, and update position based on velocity for the time step. Another
  may be a movement sytem which checks for input, and updates the velocity
  component of a player.

### Example

Here is a brief code example of what the physics system in the game that I
wrote looks like. Some things of note about this example are:

- The `run` function is called on every tick of the game loop.
- The physics implementation is quite simple, and just involves iterating
  through each entity with a `PHYSICS` and `TRANSFORM` component, and updating
  their positions and velocities for the next time step.
- ECS encourages writing systems, i.e. game logic, that are concise, single
  responsibility, and composable.

```js
const TRANSFORM = 'TRANSFORM';

const TransformComponent = (px, py, pz, orientation) => {
  return [TRANSFORM, {px, py, pz, orientation}];
};

const PHYSICS = 'PHYSICS';

const PhysicsComponent = (vx, vy, friction) => {
  return [PHYSICS, {vx, vy, basevx: 0, basevy: 0, friction}];
};

const PhysicsSystem = () => {
  const applyFriction = (f, v) => {
    if (f > Math.abs(v)) {
      return 0;
    }
    if (v > 0) {
      return v - f;
    }
    return v + f;
  };

  const run = (ctx, dt) => {
    for (const [id, physics, transform] of ctx.getEntities(
      PHYSICS,
      TRANSFORM,
    )) {
      transform.px += (physics.basevx + physics.vx) * dt;
      transform.py += (physics.basevy + physics.vy) * dt;
      if (physics.vx !== 0 || physics.vy !== 0) {
        transform.orientation =
          Math.atan2(physics.vy, physics.vx) - Math.PI / 2;
      }
      if (physics.friction !== 0) {
        const f = physics.friction * dt;
        physics.vx = applyFriction(f, physics.vx);
        physics.vy = applyFriction(f, physics.vy);
      }
    }
  };

  return {
    run,
  };
};

```

### Philosophy

The ECS pattern is highly data driven compared to other architectural patterns.
With ECS, one defines a large, segmented pool of state (components), and
separately defines business logic which operates on those components (systems).
Systems only care about and operate on the components that they are responsible
for, and entities only need to compose over the relevant components in order to
obtain behavior from systems. For example, creating a new enemy would involve
creating a new entity with collidable, position, velocity, health, and
renderable components, knowing that the physics, collision, health, and
rendering systems will ensure that its state is updated correctly each tick.
Creating new enemy types that are mechanically different also become "easy", as
a direct result of the composability of components. For example, creating a
ghost enemy that may fly through walls would only need position, velocity,
health, and renderable components, knowing that the collision system would not
operate on this new ghost entity.

ECS embraces the fact that game logic has inherently cross-cutting concerns
that involve different entities and components. This is apparent in position,
which needs to be updated both by velocity and by collision, and as such cannot
be directly "owned" by either. Collision also involves all entities with a
collidable component. This would be difficult to implement if collision data
was not managed by a single data structure.

ECS is well suited for problems where data needs to be accessed and modified
constantly by a multitude of actors, because of its focus on a separation of
data and its associated behavior. It does this, however, by giving up some
degree of encapsulation and information hiding. A more traditional object
oriented architecture is designed to hide implementation details so that other
services may depend upon a constant API contract/interface while the underlying
implementation evolves and improves. With games, the aspect of the code that
changes the most is not implementation, but instead new features and systems
that integrate tightly with the existing systems, i.e. new ways to play the
game. This unique problem is why entity component system is so prevalent in
game programming, and why it is crucial to learn for game developers.
