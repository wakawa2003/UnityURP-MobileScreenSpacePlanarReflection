#ifndef MYHLSLINCLUDE_INCLUDED
#define MYHLSLINCLUDE_INCLUDED

#include "Assets/_MobileSSPR/ReusableCore/MobileSSPRInclude.hlsl"

void GetSSR_half(float4 screenPos,float3 posWS,float2 noise,float roughness,float SSPR_Usage,out half3 o){
                ReflectionInput reflectionData;
                reflectionData.posWS = posWS;
                reflectionData.screenPos = screenPos;
                reflectionData.screenSpaceNoise = noise;
                reflectionData.roughness = roughness;
                reflectionData.SSPR_Usage = SSPR_Usage;

                o = GetResultReflection(reflectionData);
}

#endif