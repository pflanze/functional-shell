
## Memory model

All objects are passed as shortish strings that bundle both the type
and then either the object value directly ('immediate object') or a
reference, which is used to identify the filesystem item that stores
the object contents.

All mutable data types (currently: string, pair) are allocated and
passed by reference.

Currently implemented types:

 type     kind       desc                  constructor; accessors
 -------  ---------  --------------------  ---------------
 number   immediate  stringified number    number; number-value
 string   allocated  utf8-encoded string   string; string-value, string-path
 pair     allocated  pair of two objects   cons; car, cdr
 null     immediate  the empty list        nil

Each type has a type predicate which is named after the type with a
trailing 'P'.


### Memory allocation

Every data type uses its own directory for objects. The data is saved
in individual files (untagged), types bundling multiple fields use a
directory containing a file for every field (named after the field
name).

The system uses id counters stored in files to construct new ids (XXX:
concurrent access; also, for security and distribution use uuids
instead?)

^ XXX  subject to changes.
