-module(wisp_ffi).

-export([atom_from_dynamic/1]).

atom_from_dynamic(Atom) when is_atom(Atom) -> {ok, Atom};
atom_from_dynamic(_) -> {error, nil}.
