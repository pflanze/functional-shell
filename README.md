# Lisp-style functional programming in the shell

This implements an object model where potentially big or mutable
objects are stored in files to make them shareable across processes,
plus a library of pure functions (in the mathematical sense,
implemented as individual scripts) for working with them.

This is not really meant for production use, but for
learning/illustration. It is *way* slower and more obfuscated than
other functional language implementations. It aims to be correct /
precise / safe and efficient except for a big constant factor,
though. (But it isn't finished, see Todo.)

This (currently) uses Bash. Most functions / commands are implemented
as bash scripts though (as opposed to bash functions sourced as a
library), thus could be reimplemented in C instead and be used by any
other shell, too. (Alternatively, they could all (in addition?) be
offered as bash functions in a source'able file to reduce the
fork/exec overhead; although see 'Tail-call optimization' for a
problem that would arise with a pure source'ing approach.)


## Usage

1. `export PATH="<path-to>/functional-shell/system:$PATH"`

1. set MEM to a place to put the object storage, e.g.

        export MEM=~/.functional-shell

2. only once to create the object storage: 

        functional-shell-init

3. only once after booting: 

        nohup id-server & disown

   (or run in a separate terminal to see error messages as they turn
   up)

4. Test the system:

        test/str
        test/call
        test/lists
        test/boxes

5. read the code of the scripts in the [test](test) directory (and the
   text below), do your own experiments...


## Memory model

All objects are passed as shortish strings that bundle both the type
and then either the object value directly ('immediate object') or a
reference, which is used to identify the filesystem item that stores
the object contents.

All mutable data types (currently: string, pair) are allocated and
passed by reference.

Currently implemented types:

    type     kind       desc                  constructor  accessors
    -------  ---------  --------------------  -----------  -------------------------
    number   immediate  stringified number    number       number-value
    string   allocated  utf8-encoded string   string       string-value, string-path
    pair     allocated  pair of two objects   cons         car, cdr
    null     immediate  the empty list        null or nil  -
    box      allocated  a mutable box         box          unbox, box_set

Each type has a type predicate which is named after the type with a
trailing 'P'. (E.g. `pairP "$v"` will be true iff $v refers to a pair
object.)

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

For an example, see [system/list_ref](system/list_ref).

## Lambda and closures

The Bash language does not offer closures, lexical variables, or local
or anonymous functions. It does offer anonymous code as first-class
values though (any string can be called as code reference (function or
executable name), or using 'eval' even complete scripts, although
*functional-shell* doesn't make use of the latter).

Local functions (be it named or anonymous ones) in a functional
language can refer to the lexical context; since there is no mechanism
in bash to capture that context transparently, there's no way around
doing that explicitely instead.

So, the solution offered here is the following:

* There's a `closure` data type, with `code` and `env` fields. `code`
  is a reference to a bash function or executable, `env` can be
  anything (it's basically like the `void*` argument passed to
  callbacks in C), `list` can be used to bundle multiple values.

* There's also a `code` data type, that only contains code and no env;
  its purpose is (together with the `closure` type) to offer a super
  type (a "callable") that generic functions can simply `call`.
  (Example: `map` usage in [test/lists](test/lists).)

* So, to create a closure instance, run e.g.:

        cl=$(closure function_or_code_name "$(list "$val1" "$val2" "$val3")")

* to call it, run e.g.:

        call "$cl" "$val4" "$val5"

  This has the same effect as running:

        function_or_code_name "$(list "$val1" "$val2" "$val3")" "$val4" "$val5"

### Mutation of variables

Some of the languages that support first-class functions (and hence
closures), and also allow mutations of variable bindings, for example
Perl or Scheme, will make the mutations visible to all closures
referring to the same bindings. Others, like Python, do not share the
mutations between closures. Yet others (like ML or Haskell) don't
offer mutation of bindings at all; ML offers boxes.

There's no way to share variable mutations in Bash (again, they aren't
even lexical variables, thus the life time of a variable binding can
be shorter than the life time of one of our closures.) As a solution
for cases where the algorithm asks for mutable bindings, a *box* data
type is offered here. Instead of mutating variables directly, use as
follows:

    b=$(box "$val1")
    set_box "$b", "$val2"
    unbox "$b" # prints $val2

See [test/boxes](test/boxes) for an example involving
closures.


## Problems

Problems compared to some other "real" programming languages (like
Scheme or other Lisps):

* Bash offers no safe way around using double quotes around all
  variable references (except in assignment context (is this actually
  correct?)). `IFS=` is not enough in some cases (with empty strings
  as values). This entails a permanent risk of omission with
  possible implications for safety/security.

  Although, when using tagged values throughout the whole application
  (eliminating the empty string case) ditching the quotes might be
  safe again. (Find out and report back.)

* The only exception mechanism that bash offers is `set -euo
  pipefail`, but this only works in the top level contexts of files
  and function bodies, not in nested expressions. This means that for
  exception propagation to work, one cannot use subexpressions, and
  instead has to unnest them and assign temporary variables (basically
  [static single assignment
  form](https://en.wikipedia.org/wiki/Static_single_assignment_form)).
  Worse, `local` inhibits the exception propagation, too (but only
  from failing subcommands, not failing variable accesses, i.e. `set
  -u` enforces termination whereas `set -e` doesn't; crazy). All of
  this means that for example a function that can be written in Scheme
  like

        (define (map fn l)
          (if (null? l)
              '()
              (cons (fn (car l)) 
                    (map fn (cdr l)))))

  becomes

        map () {
            set -euo pipefail
            # ^ XX: necessary in every function? It was in some cases, 
            #       I have not properly tracked this down though.
            local fn="$1" # XX: is it a good idea to rely on set -u working
            local l="$2"  #     through `local` in the future?
            if nullP "$l"; then
                null
            else
                local a
                a=$(car "$l")
                local v
                v=$(call "$fn" "$a")
                local r
                r=$(cdr "$l")
                local rr
                rr=$(map "$fn" "$r")
                cons "$v" "$rr"
            fi
        }

  (Ok, the `r` intermediate variable could have been saved since
  there's no possibility for `cdr` to be failing here. But, rather be
  consistent than smart.)

  Note that a style like

                local a=$(car "$l") || die

  does not help either: `local` still clobbers the exception
  here. Bash is just that bad. (Of course this has nothing to do with
  *functional-shell* or functional programming; it's just that if you
  have an expectation of safety, you don't want programs to continue
  after running into unhandled errors.)

* The above actually clobbers exceptions happening in `nullP`. This
  could be remedied by changing predicates to return booleans via
  stdout instead of their exit code, which would also have the
  advantage of being consistent with how values are returned
  otherwise.  It will turn the above into:

        map () {
            set -euo pipefail
            local fn="$1"
            local l="$2"
            local t
            t=$(nullP "$l")
            if is_true "$t"; then
                ...


## Todo

* implement filter: this is a good exercise

* implement delay, force, lazy list (stream) library

* implement garbage collection (this will make the syntax even uglier
  since it requires registration of all bindings, which will be
  instructive for understanding but very painful; perhaps a
  memory-scanning approach can be used instead that linearly scans
  process RAM by way of ptrace or /proc/$pid/mem for reference
  strings, that should be neat if there's no superfluous retention of
  such strings by bash or malloc, but that latter point may be an
  issue; this would have an issue with references that have been
  written to pipes but not yet read (and thus are present in a kernel
  buffer only), but echo and read wrappers could be used to add/remove
  these values to/from the root set explicitely.)

