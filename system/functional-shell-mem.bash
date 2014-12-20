
# keep in sync with functional-shell-init  !

set -euo pipefail
# I won't code without this anymore I guess..:
IFS=""

error () {
    set -euo pipefail
    echo "error: $@" >&2
    exit 2
}

warn () {
    echo "warning: $@" >&2
}


type_allocatedP () {
    set -euo pipefail
    case $1 in
	string|pair)
	true
	;;
	number|null)
	false
	;;
	*)
	error "unknown type: $1"
	;;
    esac
}


# type, id -> object
make_object () {
    echo "$1 $2"
}


# object -> (), setting __type and __unsafevalue
__object_regex_match () {
    set -euo pipefail
    [[ $1 =~ ^([a-z]+)' '(.*) ]] || error "not an object: $1"
    __type=${BASH_REMATCH[1]}
    __unsafevalue=${BASH_REMATCH[2]}
}


# id -> path
id_path () {
    set -euo pipefail
    echo $MEM/cur/$1
}

# # object -> type
# object_type () {
#     __object_regex_match $1
#     echo $__type
# }

# # object -> unsafevalue
# object_unsafevalue () {
#     __object_regex_match $1
#     echo $__unsafevalue
# }

# object -> id
object_id () {
    set -euo pipefail
    __object_regex_match $1
    if type_allocatedP $__type; then
	echo $__unsafevalue
    else
	error "not an allocated object: $1"
    fi
}

# object, type -> path
object_path_of_type () {
    set -euo pipefail
    __object_regex_match $1
    [ $__type = $2 ] || error "not a $2 object: $1"
    id_path $__unsafevalue
}



# () -> id
genid () {
    set -euo pipefail
    # XXX concurrency
    local id
    id=`cat $MEM/id`
    local id2
    id2=$(( $id + 1 ))
    echo $id2 > $MEM/id
    echo $id2
}

# type, {fieldname, fieldvalue} ...  -> object
alloc_record () {
    set -euo pipefail
    local type
    type=$1
    shift
    local id
    id=`genid`
    local path
    path=`id_path $id`
    mkdir $path
    local name
    local val
    while [ $# -ne 0 ]; do
	name=$1
	val=$2
	shift
	shift
	echo $val > $path/$name
    done
    make_object $type $id
}

# type, (object, path -> A) -> A
alloc_file () {
    set -euo pipefail
    local type
    local cont
    type=$1
    cont=$2

    local id
    id=`genid`
    local path
    path=`id_path $id`
    local object
    object=`make_object $type $id`

    $cont $object $path
}

