//
//  HomepodRimGlow.metal
//  UP_AR (UniPlace)
//
//  Fresnel rim-glow surface shader for the HomePod "this is interactive" shell (a slightly enlarged
//  copy of the body). Head-on the surface is fully transparent; toward the silhouette it becomes a
//  soft glow that tops out at ~0.6 opacity. The shell's overall fade-in by viewer proximity is driven
//  separately on the Swift side via OpacityComponent (a handheld has no hover state to key off).
//
//  This is the project's first CustomMaterial shader. It is compiled into the app's default Metal
//  library automatically (the target uses file-system-synchronized groups), and referenced by the
//  function name `homepodRimSurface` from `HomepodProcessor.makeRimMaterial()`.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void homepodRimSurface(realitykit::surface_parameters params)
{
    constexpr float kPower = 2.0;          // edge tightness — higher = thinner rim
    constexpr float kMaxOpacity = 0.7;     // opacity right at the silhouette
    constexpr float kEmissiveBoost = 1.3;  // brighten the glow toward the edge
    const float3 kGlow = float3(0.25, 0.95, 1.0);

    float3 n = normalize(params.geometry().normal());
    float3 v = normalize(params.geometry().view_direction());
    float facing = saturate(abs(dot(n, v))); // 1 head-on, 0 at the grazing edge (abs ⇒ sign-agnostic)
    float rim = pow(1.0 - facing, kPower);    // 0 head-on, →1 at the edge

    auto surface = params.surface();
    surface.set_base_color(half3(kGlow));
    surface.set_emissive_color(half3(kGlow * rim * kEmissiveBoost));  // unlit ⇒ emissive == final colour
    surface.set_opacity(half(rim * kMaxOpacity));
}
