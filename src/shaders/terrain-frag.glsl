#version 300 es
precision highp float;

uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane
uniform float u_Snowfall;
uniform int u_Time;

in vec4 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_Col;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.


vec3 c_seed = vec3(0);
float PI = 3.14159265;
float PI_2 = 6.2831853;

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

// 2D Perlin Noise
/////////////////////////////////////////
// Falloff founction from CIS566 course slides
float falloff(float t) {
  t = t * t * t * (t * (t * 6. - 15.) + 10.);
  return t;
}

vec2 randGrad(vec2 p, vec2 seed) {
  float randDeg = random1(p, seed) * PI_2;
  return vec2(cos(randDeg), sin(randDeg));
}

float PerlinNoise(vec2 p, float s) {
    p /= s;
    vec2 pCell = floor(p);
    p -= pCell;
    float dotGrad00 = dot(randGrad(pCell + vec2(0., 0.), c_seed.xz), p - vec2(0., 0.));
    float dotGrad01 = dot(randGrad(pCell + vec2(0., 1.), c_seed.xz), p - vec2(0., 1.));
    float dotGrad10 = dot(randGrad(pCell + vec2(1., 0.), c_seed.xz), p - vec2(1., 0.));
    float dotGrad11 = dot(randGrad(pCell + vec2(1., 1.), c_seed.xz), p - vec2(1., 1.));

    return mix(mix(dotGrad00, dotGrad10, falloff(p.x)), mix(dotGrad01, dotGrad11, falloff(p.x)), falloff(p.y)) * .5 + .5;
}

float FBMPerlinSnow(vec2 p) {
    float sum = 0.;
    float noise = 0.;
    int maxIter = 3;
    float minCell = 3.;
    for (int i = 0; i < maxIter; i++) {
      float weight = mix(1. / float(maxIter - i), 1. / pow(float(maxIter - i), 2.), u_Snowfall);
      noise += (1. - PerlinNoise(p, minCell * pow(2., float(i)))) * weight;
      sum += weight;
    }
    noise /= sum;
    return noise;
}

// 3D Perlin Noise
/////////////////////////////////////////
vec3 randGrad(vec3 p, vec3 seed) {
  switch(int(floor(random1(p, seed) * 6.))) {
    case 0: return vec3(1., 0., 0.);
    case 1: return vec3(-1., 0., 0.);
    case 2: return vec3(0., 1., 0.);
    case 3: return vec3(0., -1., 0.);
    case 4: return vec3(0., 0., 1.);
    default: return vec3(0., 0., -1.);
  }
}

float PerlinNoise(vec3 p, float s) {
    p /= s;
    vec3 pCell = floor(p);
    p -= pCell;
    float dotGrad000 = dot(randGrad(pCell + vec3(0., 0., 0.), c_seed), p - vec3(0., 0., 0.));
    float dotGrad010 = dot(randGrad(pCell + vec3(0., 1., 0.), c_seed), p - vec3(0., 1., 0.));
    float dotGrad100 = dot(randGrad(pCell + vec3(1., 0., 0.), c_seed), p - vec3(1., 0., 0.));
    float dotGrad110 = dot(randGrad(pCell + vec3(1., 1., 0.), c_seed), p - vec3(1., 1., 0.));
    float dotGrad001 = dot(randGrad(pCell + vec3(0., 0., 1.), c_seed), p - vec3(0., 0., 1.));
    float dotGrad011 = dot(randGrad(pCell + vec3(0., 1., 1.), c_seed), p - vec3(0., 1., 1.));
    float dotGrad101 = dot(randGrad(pCell + vec3(1., 0., 1.), c_seed), p - vec3(1., 0., 1.));
    float dotGrad111 = dot(randGrad(pCell + vec3(1., 1., 1.), c_seed), p - vec3(1., 1., 1.));

    float mixedDGX00 = mix(dotGrad000, dotGrad100, falloff(p.x));
    float mixedDGX10 = mix(dotGrad010, dotGrad110, falloff(p.x));
    float mixedDGX01 = mix(dotGrad001, dotGrad101, falloff(p.x));
    float mixedDGX11 = mix(dotGrad011, dotGrad111, falloff(p.x));

    float mixedDGY0 = mix(mixedDGX00, mixedDGX10, falloff(p.y));
    float mixedDGY1 = mix(mixedDGX01, mixedDGX11, falloff(p.y));

    return mix(mixedDGY0, mixedDGY1, falloff(p.z)) * .5 + .5;
}

float FBMPerlin(vec3 p) {
    float sum = 0.;
    float noise = 0.;
    int maxIter = 4;
    float minCell = 2.;
    for (int i = 0; i < maxIter; i++) {
        noise += PerlinNoise(p, minCell * pow(2., float(i))) / pow(2., float(maxIter - i));
        sum += 1. / pow(2., float(maxIter - i));
    }
    noise /= sum;
    return noise;
}

float warpFBMPerlin(vec3 p, int time) {
  vec3 q = vec3(FBMPerlin(p + vec3(0. + 0.5 * float(u_Time),0., 0.)) + 0.003 * float(u_Time),
                FBMPerlin(p + vec3(3., 5., 2.)),
                FBMPerlin(p + vec3(2., -1., 1.)));
  return FBMPerlin(p + 30.0 * q);
}


void main()
{
  float t = clamp(smoothstep(40.0, 50.0, length(fs_Pos.xyz)), 0.0, 1.0); // Distance fog
  vec3 col = mix(mix(vec3(0), vec3(0.2), sqrt(abs(fs_Pos.y))), vec3(1.), smoothstep(0.05, 0.2, 1. - fs_Pos.w) * (fs_Pos.y * 0.3 + 0.7));

  float fog_noise = smoothstep(0.3, 0.6, warpFBMPerlin(vec3(u_PlanePos.x + fs_Pos.x, fs_Pos.y * 20., u_PlanePos.y + fs_Pos.z), u_Time)) * pow((1. - fs_Pos.y), 2.);
  col = mix(col, vec3(0.88, 0.97, 1.0), fog_noise);

  vec3 ori_col = mix(mix(vec3(58., 52., 63.) / 255., mix(vec3(0.2), vec3(0.58, 0.60, 0.53), abs(fs_Pos.y)), sqrt(abs(fs_Pos.y))), vec3(0.58, 0.60, 0.53), smoothstep(0., 0.5, 1. - fs_Pos.w) * abs(fs_Pos.y));
  float snow = mix(smoothstep(0.3, 0.7, FBMPerlinSnow(fs_Pos.xz + u_PlanePos)) * u_Snowfall, 1., u_Snowfall * u_Snowfall);
  col = mix(ori_col, col, snow);
  //out_Col = vec4(mix(col, vec3(164.0 / 255.0, 233.0 / 255.0, 1.0), t), 1.0);
  out_Col = vec4(col, 1. - t);
}
