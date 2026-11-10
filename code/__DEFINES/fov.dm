/// Field of vision defines.
#define FOV_90_DEGREES 90
#define FOV_180_DEGREES 180
#define FOV_270_DEGREES 270
#define FOV_REVERSE_90_DEGRESS -90
#define FOV_REVERSE_180_DEGRESS -180
#define FOV_REVERSE_270_DEGRESS -270

/// Base mask dimensions. They're like a client's view, only change them if you modify the mask to different dimensions.
#define BASE_FOV_MASK_X_DIMENSION 15
#define BASE_FOV_MASK_Y_DIMENSION 15

/// Range at which FOV effects treat nearsightness as blind and play
#define NEARSIGHTNESS_FOV_BLINDNESS 2

/// Soft round mask (light_352, 11x11 tiles) the examine balloons are clipped to around the viewer, fading them out towards 5 tiles
#define EXAMINE_BALLOON_RANGE_MASK_ICON 'icons/effects/light_overlays/light_352.dmi'
/// Half of the mask icon minus half a tile: how far it is pulled back so it sits centered on the viewer's tile
#define EXAMINE_BALLOON_RANGE_MASK_CENTERING -160
/// The balloons hover a tile above their wallmount, both of their masks are sampled that far down, at the wallmount itself
#define EXAMINE_BALLOON_MASK_SAMPLE_OFFSET 32
/// How long the examine balloons plane master takes to fade in and out
#define EXAMINE_BALLOON_FADE_TIME (0.2 SECONDS)

//Fullscreen overlay resolution in tiles for the clients view.
/// The fullscreen overlay in tiles for x axis
#define FULLSCREEN_OVERLAY_RESOLUTION_X 15
/// The fullscreen overlay in tiles for y axis
#define FULLSCREEN_OVERLAY_RESOLUTION_Y 15
