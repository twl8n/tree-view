
#### Tree drawing using only images and plain HTML

Tile based method of drawing trees in HTML without resorting to JavaScript or CSS. It takes 8 specific tiles and an algorithm to keep the tree balanced.

A Perl version of the render algo is in render-tree.pl. Do something like `perl render-tree.pl > tmp.html` and
open tmp.html in your browser. Some crude data is in @data in render-tree.pl.

There is also static demo:

https://htmlpreview.github.io/?https://github.com/twl8n/tree-view/blob/main/demo1.html

#### What is it good for?

This might have commercial value as a viewer that is part of a large product. For example, the UI for a
workflow manager. Perhaps the UI for a visual programming tool. It draws a visual representation of a work
flow driver state machine.

The actual state machine is a seprate application.


#### How do those arrow connectors work?

There are 8 connectors. They are named based on a tile numbering system that views the tiles as octogons. A `a` suffix denotes an arrow.

```
0  1  2
7     3
6  5  4
```

05 is a line from 0 to 5. 05a is an arrow from 0 to 5.

7374 is a combination line from 7 to 3 and 7 to 4.

As far as I can tell, all variants of forward progressing (directed), non-looping (acyclic) trees (graphs) can be drawn with these tiles.


#### todo

* check/fix connector image names based on directionality. 7336 probably should be 3736.
* rewrite all the Perl in Clojure
* attach this to a state machine
* add "edit", "delete", "new" features to nodes
* add node properties
* upgrade the UI with modern tech


#### About this type of state machine visualized.

By constraining behavior in certain ways, extremely reliable work flows can be created. Kelton Flinn used this
idea for critter brains (aka non-player characters) in the Island of Kesmai. Those critter drivers ran
24/7/365 for years with close to zero failures. Certainly, other code used by the drivers had bugs, but the
nature of the work flow drivers themselves minimized the impact of bugs elsewhere in the system.

There are a few variants of this particular type of state machine.

In general, what works well is to treat the machine like a round-based game. Execution always starts at the
root of the tree. After halting, loop to the root for the next round.

Node behavior can have several variants.

* Each node runs a function (with or without a side effect), and dispatches based on the function's return value.
* Each has a function. Some functions are booleans tests, and branching is based on the result. Non-boolean nodes run a side-effect-y function. At leaf nodes, the machine halts. 

All "state" is external to the driver, and tested or set via functions. The state machine is only able to test
state by calling functions.
