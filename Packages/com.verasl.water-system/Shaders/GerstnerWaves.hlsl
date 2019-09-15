﻿#ifndef GERSTNER_WAVES_INCLUDED
#define GERSTNER_WAVES_INCLUDED

uniform uint 	_WaveCount; // how many waves, set via the water component

struct Wave
{
	half amplitude;
	half direction;
	half wavelength;
	half2 origin;
	half omni;
};

#if defined(USE_STRUCTURED_BUFFER)
StructuredBuffer<Wave> _WaveDataBuffer;
#else
half4 waveData[20]; // 0-9 amplitude, direction, wavelength, omni, 10-19 origin.xy
#endif

struct WaveStruct
{
	float3 position;
	float3 normal;
};

WaveStruct GerstnerWave(half2 pos, float waveCountMulti, half amplitude, half direction, half wavelength, half omni, half2 omniPos)
{
	WaveStruct waveOut;

	////////////////////////////////wave value calculations//////////////////////////
	half3 wave = 0; // wave vector
	half w = 6.28318 / wavelength; // 2pi over wavelength(hardcoded)
	half wSpeed = sqrt(9.8 * w); // frequency of the wave based off wavelength
	half peak = 1; // peak value, 1 is the sharpest peaks
	half qi = peak / (amplitude * w * _WaveCount);

	direction = radians(direction); // convert the incoming degrees to radians, for directional waves
	half2 dirWaveInput = half2(sin(direction), cos(direction)) * (1 - omni);
	half2 omniWaveInput = (pos - omniPos) * omni;

	half2 windDir = normalize(dirWaveInput + omniWaveInput); // calculate wind direction
	half dir = dot(windDir, pos - (omniPos * omni)); // calculate a gradient along the wind direction

	////////////////////////////position output calculations/////////////////////////
	half calc = dir * w + -_Time.y * wSpeed; // the wave calculation
	half cosCalc = cos(calc); // cosine version(used for horizontal undulation)
	half sinCalc = sin(calc); // sin version(used for vertical undulation)

	// calculate the offsets for the current point
	wave.xz = qi * amplitude * windDir.xy * cosCalc;
	wave.y = ((sinCalc * amplitude)) * waveCountMulti;// the height is divided by the number of waves
	
	////////////////////////////normal output calculations/////////////////////////
	half wa = w * amplitude;
	// normal vector
	half3 n = half3(-(windDir.xy * wa * cosCalc),
					1-(qi * wa * sinCalc));

	////////////////////////////////assign to output///////////////////////////////
	waveOut.position = wave * saturate(amplitude * 10000);
	waveOut.normal = (n * waveCountMulti);

	return waveOut;
}

inline void SampleWaves(float3 position, half opacity, out WaveStruct waveOut)
{
	half2 pos = position.xz;
	WaveStruct waves[10];
	waveOut.position = 0;
	waveOut.normal = 0;
	half waveCountMulti = 1.0 / _WaveCount;
	half3 opacityMask = saturate(half3(3, 3, 1) * opacity);
	
	UNITY_LOOP
	for(uint i = 0; i < _WaveCount; i++)
	{
		#if defined(USE_STRUCTURED_BUFFER)
		waves[i] = GerstnerWave(pos,
								waveCountMulti, 
								_WaveDataBuffer[i].amplitude, 
								_WaveDataBuffer[i].direction, 
								_WaveDataBuffer[i].wavelength, 
								_WaveDataBuffer[i].omni, 
								_WaveDataBuffer[i].origin); // calculate the wave		
		#else
		waves[i] = GerstnerWave(pos,
        								waveCountMulti, 
        								waveData[i].x, 
        								waveData[i].y, 
        								waveData[i].z, 
        								waveData[i].w, 
        								waveData[i + 10].xy); // calculate the wave

		#endif
		waveOut.position += waves[i].position; // add the position
		waveOut.normal += waves[i].normal; // add the normal
	}
	waveOut.position *= opacityMask;
}

#endif // GERSTNER_WAVES_INCLUDED