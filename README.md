# Lisp-style functional programming in the shell

This implements an object model where potentially big or mutable
objects are stored in files to make them shareable across processes,
plus a library of functions for working with them with functional
principles.

This is not meant for production use, but for learning/illustration.


## Usage

1. `export PATH="<path-to>/functional-shell/system:$PATH"`

2. `functional-shell-init`

3. `nohup id-server & disown`

4. `test/str`; `test/lists`

5. read the code of the test scripts, then do your own experiments...


## Memory model

All objects are passed as shortish strings that bundle both the type
and then either the object value directly ('immediate object') or a
reference, which is used to identify the filesystem item that stores
the object contents.

All mutable data types (currently: string, pair) are allocated and
passed by reference.

Currently implemented types:

    type     kind       desc                  constructor  accessors
    -------  ---------  --------------------  -----------  ----------------
    number   immediate  stringified number    number       number-value
    string   allocated  utf8-encoded string   string       string-value, string-path
    pair     allocated  pair of two objects   cons         car, cdr
    null     immediate  the empty list        null or nil  -

Each type has a type predicate which is named after the type with a
trailing 'P'.

### Memory allocation

'Memory' is allocated by getting an id from the id-server and using
that as the name for either the directory (records like pair) or file
(single-field objects like string) to hold the data. The files of the
former contain objects, the files of the latter binary data.

The constructor and accessor functions form an abstraction layer:
memory allocation should only be done by the constructors, and
accesses by the accessor functions, both of which hide the low-level
details from the user.


## Tail-call optimization

There's no way to do optimized tail-calls to bash functions. Thus
programs that need optimized tail-calls would either have to use
trampolines, or more idiomatically, call the target 'function' as an
external program using 'exec' (which is more uniform, too, but of
course slower.)


## Todo

* implement lambda

* implement map, filter: this is a good exercise

* implement delay, force, lazy list (stream) library

* implement garbage collection

