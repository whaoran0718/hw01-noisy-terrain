#version 300 es
precision highp float;

uniform mat4 u_ViewProjInv;
uniform vec2 u_Dimension;
uniform int u_Time;

out vec4 out_Col;

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


// Worley Noise
/////////////////////////////////////////
vec2 sampleInCell(vec2 p) {
  return random2(p, c_seed.xz) + p;
}

float worleyNoise(vec2 p, float s) {
    // Which cell p belongs to
    p /= s;
    vec2 pCell = floor(p);

    float min_dist = 1.;
    for (int i = -1; i <= 1 ; i++) {
        for (int j = -1; j <= 1; j++) {
          vec2 sampleNoise = sampleInCell(pCell + vec2(i, j));
          min_dist = min(min_dist, distance(sampleNoise, p));
        }
    }
    float noise = clamp(min_dist + random1(pCell, c_seed.xz) * 0.2, 0., 1.);
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
float FBMPerlin(vec2 p, float minCell, int maxIter) {
    float sum = 0.;
    float noise = 0.;
    for (int i = 0; i < maxIter; i++) {
        noise += PerlinNoise(p, minCell * pow(2., float(i))) / pow(2., float(maxIter - i));
        sum += 1. / pow(2., float(maxIter - i));
    }
    noise /= sum;
    return noise;
}

float warpFBMPerlin(vec2 p, int time) {
  vec2 q = vec2(FBMPerlin(p + vec2(0.+ 0.04 * float(u_Time), 0.), 0.5, 6),
                FBMPerlin(p + vec2(1., 5.), 0.5, 6) + 0.002 * float(u_Time));
  return FBMPerlin(p + vec2(2., 10.) * q, 0.4, 4);
}

// Straight Line
/////////////////////////////////////////
float line(vec2 p) {
  float c = 0.;
  float w = 0.3;
  float x = p.x;
  x = abs(x - c);
  if (x > w) return 0.;
  x /= w;
  return 1. - x * x * (3. - 2. * x);
}


vec3 skyRamp(vec3 dir) {
  float cosUp = dir.y;
  vec3 col1 = vec3(32., 65., 80.)/255.;
  vec3 col2 = vec3(35., 34., 77.)/255.;
  vec3 col3 = vec3(12., 19., 36.)/255.;
  vec3 col4 = vec3(3., 7., 15.)/255.;

  vec3 col;
  if (cosUp < 0.0) {
    col = col1;
  }
  else if (cosUp < 0.2) {
    col = mix(col1, col2, cosUp / 0.2);
  }
  else if (cosUp < 0.5) {
    col = mix(col2, col3, (cosUp - 0.2)/0.3);
  }
  else {
    col = mix(col3, col4, (cosUp - 0.5)/0.5);
  }
  return col;
}


void main() {
  vec3 dir = normalize(vec3(u_ViewProjInv * 1000. * vec4(gl_FragCoord.xy / u_Dimension * 2. - 1., 1., 1.)));
  vec3 col = skyRamp(dir);

  float theta = acos(dir.y);
  float phi = atan(dir.z, dir.x);
  vec2 orient = vec2(theta, phi);

  float star = smoothstep(0.3, 0.7, FBMPerlin(orient, 0.03, 6)) * smoothstep(0.1, 0.55, pow(1. - worleyNoise(orient, 0.02), 15.)) * (random1(orient, c_seed.xz + floor(float(u_Time) / 10.)) * 0.5 + 0.5);
  float cloud = 0.;
  if (dir.y > 0.) {
    cloud = FBMPerlin(dir.xz / dir.y + vec2(0.002 * float(u_Time)), 0.1, 4) * smoothstep(0.01, 0.3, dir.y);
  }

  float aurora = 0.;
  if (dir.y > 0.3) {
    vec2 offset = vec2(warpFBMPerlin(dir.xz / dir.y, 0) * 2. - 1., warpFBMPerlin(dir.xz / dir.y + vec2(2., 3.), 0) * 2. - 1.);
    aurora = line(dir.xz / dir.y + offset) * smoothstep(0.3, 0.5, dir.y);
  }
  
  col = col + star + smoothstep(0.4, 0.9, cloud)* 0.2;
  vec3 auroraCol = vec3(122., 218., 113.) / 255.;
  out_Col = vec4(mix(col, auroraCol, aurora * aurora), 1.0);
}
