#include <metal_stdlib>
using namespace metal;

// Point-mass thin-lens approximation, bounded screen sampling, artistic rim.
// Not strong-field relativistic ray tracing. No accretion disk or particle vortex.
struct Uniforms {
    float2 resolution;
    float time, progress;
    float size, gravity, speed, travel;
    float preview, textureMode, reducedMotion;
    float movementTime;
    float2 center;
    float radius, customImage, assetAspect, lensReach, rimBrightness, rimWidth;
};
struct VertexOut { float4 position [[position]]; float2 uv; };
vertex VertexOut vertexMain(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return {float4(p*2.-1.,0,1),float2(p.x,1.-p.y)};
}
float hash21(float2 p) { return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
float3 sky(float2 uv,float2 resolution,float mode) {
    float2 p=uv*resolution/2.;
    if(mode>1.5) {
        float2 grid=abs(fract(p/40.-.5)-.5)/max(fwidth(p/40.),float2(.001));
        float lines=1.-min(min(grid.x,grid.y),1.);
        return float3(.032,.039,.049)+float3(.13,.18,.22)*lines;
    }
    float2 cell=floor(p/46.);
    float2 off=float2(hash21(cell),hash21(cell+13.))*.8+.1;
    float star=pow(max(0.,1.-length(fract(p/46.)-off)*38.),3.)*step(.48,hash21(cell+28.));
    return float3(.014,.019,.027)+float3(.7,.78,.95)*star;
}
float3 sampleScene(float2 uv,constant Uniforms &u,texture2d<float> scene) {
    constexpr sampler samp(coord::normalized,address::clamp_to_edge,filter::linear);
    if(u.textureMode>.5 && u.textureMode<1.5) {
        float sourceAspect=float(scene.get_width())/float(scene.get_height());
        float aspect=u.resolution.x/u.resolution.y;
        if(u.preview>.5) {
            if(aspect>sourceAspect) uv.y=(uv.y-.5)*sourceAspect/aspect+.5;
            else uv.x=(uv.x-.5)*aspect/sourceAspect+.5;
        }
        return scene.sample(samp,uv).rgb;
    }
    return sky(uv,u.resolution,u.textureMode);
}
fragment float4 fragmentMain(VertexOut v [[stage_in]],constant Uniforms &u [[buffer(0)]],
                            texture2d<float> scene [[texture(0)]],texture2d<float> asset [[texture(1)]]) {
    float g=clamp(u.progress,0.,1.);
    if(g<=0. || u.radius<=0.) return u.preview>.5 ? float4(sampleScene(v.uv,u,scene),1.) : float4(0.);
    float2 metric=float2(u.resolution.x/u.resolution.y,1.);
    float2 p=(v.uv-u.center)*metric;
    float r=length(p), radius=max(u.radius,.000001), nr=r/radius;
    float reach=radius*(3.+clamp(u.lensReach,.5,2.)*3.);
    // Do not early-return by radius: fwidth needs the neighboring fragment lanes.
    // Divergent returns here create a dotted circular seam at the field boundary.
    float strength=clamp(u.gravity/10.,0.,1.);
    float taper=1.-smoothstep(radius*1.8,reach,r);
    // beta = theta - theta_E^2/theta. Tangential arcs, not rotation of the desktop.
    // Soften the central singularity when the custom asset has transparent pixels.
    float einsteinSquared=radius*radius*strength*3.4;
    float softening=u.customImage>.5 ? radius*radius*.16 : 0.;
    float2 displacement=-p*einsteinSquared/max(r*r+softening,radius*radius*.01)*taper;
    float2 rawUV=v.uv+displacement/metric;
    float edgeDistance=min(min(rawUV.x,1.-rawUV.x)*metric.x,min(rawUV.y,1.-rawUV.y));
    float safe=smoothstep(0.,max(.015,radius*.25),edgeDistance);
    float2 uv=v.uv+displacement/metric*safe;
    float3 bg=sampleScene(uv,u,scene);
    float3 foreground=float3(0.);
    float material=0.;
    if(u.customImage>.5) {
        float2 halfSize=radius*1.45*float2(min(1.,u.assetAspect),min(1.,1./u.assetAspect));
        float2 imageUV=p/(2.*halfSize)+.5;
        if(all(imageUV>=0.) && all(imageUV<=1.)) {
            constexpr sampler imageSampler(coord::normalized,address::clamp_to_edge,filter::linear);
            float4 image=asset.sample(imageSampler,imageUV);
            material=image.a; foreground=image.rgb;
        }
    } else {
        float aa=max(fwidth(nr),.002);
        float shadow=1.-smoothstep(1.-aa,1.+aa,nr);
        float width=max(u.rimWidth,aa);
        float ring=exp(-pow((nr-1.035)/width,2.));
        float shoulder=exp(-pow((nr-1.09)/(.11+width),2.))*.26;
        float angle=atan2(p.y,p.x);
        float time=u.reducedMotion>.5 ? 0. : u.time;
        float brightness=clamp(u.rimBrightness,0.,2.)*(.9+.1*cos(angle-time*.12));
        float glow=(ring+shoulder)*brightness*(1.-shadow);
        float3 rimColor=mix(float3(.82,.89,1.),float3(1.,.86,.65),.5+.5*sin(angle));
        float rimAlpha=clamp(glow,0.,1.);
        material=shadow+rimAlpha*(1.-shadow);
        foreground=rimColor*rimAlpha*(1.-shadow);
    }
    if(u.preview>.5) return float4(foreground+bg*(1.-material),1.);
    // The boundary is already an identity mapping before overlay alpha fades.
    float fieldAlpha=u.textureMode>.5 ? (1.-smoothstep(reach*.8,reach,r))*step(.00001,strength) : 0.;
    float alpha=material+fieldAlpha*(1.-material);
    return float4(foreground+bg*fieldAlpha*(1.-material),alpha);
}
