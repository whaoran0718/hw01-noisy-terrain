#version 300 es
precision highp float;

uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane
uniform float u_Sharpness;  // Sharpness of mountain

in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

out vec4 fs_Pos;
out vec4 fs_Nor;
out vec4 fs_Col;

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


// 3D Worley Noise
/////////////////////////////////////////
vec3 sampleInCell3D(vec3 p) {
    vec2 r = random2(p.xz, c_seed.xz);
    return vec3(r.x, random1(p, c_seed), r.y) + p;
}

float worleyNoise(vec3 p, float s) {
    // Which cell p belongs to
    p /= s;
    vec3 pCell = floor(p);

    float min_dist = 1.;
    for (int i = -1; i <= 1 ; i++) {
        for (int j = -1; j <= 1; j++) {
          for (int k = -1; k <= 1; k++) {
            vec3 sampleNoise = sampleInCell3D(pCell + vec3(i, j, k));
            min_dist = min(min_dist, distance(sampleNoise, p));
          }
        }
    }
    float noise = clamp(min_dist, 0., 1.);
    return noise;
}


// Perlin Noise
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


// FBM Noise
/////////////////////////////////////////
int maxIter = 4;
float minCell = 3.;
float FBMPerlin(vec2 p) {
    float sum = 0.;
    float noise = 0.;
    for (int i = 0; i < maxIter; i++) {
        noise += PerlinNoise(p, minCell * pow(2., float(i))) / pow(2., float(maxIter - i));
        sum += 1. / pow(2., float(maxIter - i));
    }
    noise /= sum;
    return noise;
}

// Perturbed FBM Noise
/////////////////////////////////////////
float warpFBMPerlin(vec2 p) {
  vec2 q = vec2(FBMPerlin(p + vec2(0.,0.)),
                FBMPerlin(p + vec2(20.,10.)));
  return FBMPerlin(p + 30.0 * q);
}


// Height Map
/////////////////////////////////////////
float heightMap(vec2 p) {
  float noise = warpFBMPerlin(p);
  return smoothstep(0.4, 0.7 + u_Sharpness * u_Sharpness * 0.1, noise);
}

// Gradient
/////////////////////////////////////////
vec3 gradient(vec2 p, float hScale) {
  float gradX = heightMap(p + vec2(0.5, 0.)) - heightMap(p - vec2(0.5, 0.));
  float gradZ = heightMap(p + vec2(0., 0.5)) - heightMap(p - vec2(0., 0.5));
  if (gradX == 0. && gradZ == 0.) {
    return vec3(0., 0., 0.);
  } 
  
  vec2 grad2D = vec2(gradX, gradZ) * hScale;
  vec2 normGrad2D = normalize(grad2D);
  return normalize(vec3(normGrad2D.x, length(grad2D), normGrad2D.y));
}

void main()
{
  float sharp = u_Sharpness * u_Sharpness;

  float height = heightMap(vs_Pos.xz + u_PlanePos);
  float noise3D = worleyNoise(vec3(vs_Pos.x + u_PlanePos.x, height * 25., vs_Pos.z + u_PlanePos.y), 10.);
  vec3 grad = gradient(vs_Pos.xz + u_PlanePos, 30.);
  vec2 offset = vec2(0.);

  if (length(-grad.xz) != 0.) {
    offset = normalize(-grad.xz) * (1.0 - noise3D) * 5. * smoothstep(0.05, 1.0, height) * (1. - sharp);
  }

  fs_Col = vec4(0);
  fs_Pos = vec4(vs_Pos.x + offset.x, height, vs_Pos.z + offset.y, grad.y);
  vec4 modelposition = vec4(vs_Pos.x + offset.x, height * (15. + 10. * sharp) - 10., vs_Pos.z + offset.y, 1.);
  modelposition = u_Model * modelposition;
  gl_Position = u_ViewProj * modelposition;
}
