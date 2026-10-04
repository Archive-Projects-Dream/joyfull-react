/// Type is abstract and should be skipped in type iterations, etc.
#define IS_ABSTRACT(datum_type) (initial(datum_type.abstract_type) == datum_type)

/// One shared list instance for the whole world (see smoothwall.dm). Using a
/// macro that expands to a list() literal would build a fresh copy on every
/// atom creation, and the tiles_with typecache is keyed by list identity.
#define BASED_TILES GLOB.base_tiles
