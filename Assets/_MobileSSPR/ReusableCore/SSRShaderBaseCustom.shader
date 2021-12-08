
Shader "MobileSSPR/SSRShaderBaseCustom"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("BaseMap", 2D) = "black" {}

        _Roughness("_Roughness", range(0,1)) = 0.25
        [NoScaleOffset]_SSPR_UVNoiseTex("_SSPR_UVNoiseTex", 2D) = "gray" {}
        _SSPR_NoiseIntensity("_SSPR_NoiseIntensity", range(-0.2,0.2)) = 0.0

        _UV_MoveSpeed("_UV_MoveSpeed (xy only)(for things like water flow)", Vector) = (0,0,0,0)

        [NoScaleOffset]_ReflectionAreaTex("_ReflectionArea", 2D) = "white" {}
         _ReflectionIntensity("_ReflectionIntensity", range(0,1)) = 0.1
         _PowerReflectionIntensity("_PowerReflectionIntensity", range(0,10)) = 1
         _Freshnel("_Freshnel", range(-0,20)) = 0.0

    }

    SubShader
    {
        Pass
        {
            //================================================================================================
            //if "LightMode"="MobileSSPR", this shader will only draw if MobileSSPRRendererFeature is on
            Tags { "LightMode" = "MobileSSPR" }
            //================================================================================================

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //================================================================================================
            #include "Assets/_MobileSSPR/ReusableCore/MobileSSPRInclude.hlsl"
            #pragma multi_compile _ _MobileSSPR
            //================================================================================================

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                half3 normal        : NORMAL;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 screenPos    : TEXCOORD1;
                float3 posWS        : TEXCOORD2;
                float4 positionHCS  : SV_POSITION;
                half3 normal        : TEXCOORD3;
            };

            //textures
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_SSPR_UVNoiseTex);
            SAMPLER(sampler_SSPR_UVNoiseTex);
            TEXTURE2D(_ReflectionAreaTex);
            SAMPLER(sampler_ReflectionAreaTex);

            //cbuffer
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _SSPR_NoiseIntensity;
            float2 _UV_MoveSpeed;
            half _Roughness;
            half _Freshnel;
            half _ReflectionIntensity;
            half _PowerReflectionIntensity;

            CBUFFER_END


            //ham dung san
            float FresnelEffect(float3 Normal, float3 ViewDir, float Power)
            {
                return pow((1.0 - saturate(dot(normalize(Normal), normalize(ViewDir)))), Power);
            }

            void Unity_Blend_Screen_float4(float4 Base, float4 Blend, float Opacity, out float4 Out)
            {
                Out = 1.0 - (1.0 - Blend) * (1.0 - Base);
                Out = lerp(Base, Out, Opacity);
            } 
            
            void Unity_Blend_Screen_float4(half3 Base, half3 Blend, float Opacity, out half3 Out)
            {
                Out = 1.0 - (1.0 - Blend) * (1.0 - Base);
                Out = lerp(Base, Out, Opacity);
            }

            void Unity_Blend_Multiply_float4(half3 Base, half3 Blend, float Opacity, out half3 Out)
            {
                Out = Base * Blend;
                Out = lerp(Base, Out, Opacity);
            }

            void Unity_Blend_HardLight_float4(half3 Base, half3 Blend, float Opacity, out half3 Out)
            {
                half3 result1 = 1.0 - 2.0 * (1.0 - Base) * (1.0 - Blend);
                half3 result2 = 2.0 * Base * Blend;
                half3 zeroOrOne = step(Blend, 0.5);
                Out = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
                Out = lerp(Base, Out, Opacity);
            }
            ////////////////////////////////


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap) + _Time.y * _UV_MoveSpeed;
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                OUT.posWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);

                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //base color
                half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor.rgb;

                //noise texture
                float2 noise = SAMPLE_TEXTURE2D(_SSPR_UVNoiseTex,sampler_SSPR_UVNoiseTex, IN.uv);
                noise = noise * 2 - 1;
                noise.y = -abs(noise); //hide missing data, only allow offset to valid location
                noise.x *= 0.25;
                noise *= _SSPR_NoiseIntensity;

                //get light data
                Light light = GetMainLight();
                half3 lightDirection = light.direction;
                half3  customLight = dot(lightDirection, IN.normal)*0.5;
                half3 viewDir=_WorldSpaceCameraPos - IN.posWS;

                float blendValue= FresnelEffect(IN.normal, viewDir, 0.5);
                
                //================================================================================================
                //GetResultReflection from SSPR

                ReflectionInput reflectionData;
                reflectionData.posWS = IN.posWS -IN.normal*3;//tao hieu ung that hon
                reflectionData.screenPos = IN.screenPos;
                reflectionData.screenSpaceNoise = noise*dot(-1,IN.normal);
                reflectionData.roughness = _Roughness;
                reflectionData.SSPR_Usage = _BaseColor.a;

                half3 resultReflection = GetResultReflection(reflectionData);
                //================================================================================================
   
            
                //decide show reflection area
                //   half3  finalRGB = lerp(baseColor,resultReflection,reflectionArea);//code goc 
                half reflectionArea = SAMPLE_TEXTURE2D(_ReflectionAreaTex,sampler_ReflectionAreaTex, IN.uv);



                half3 finalRGB = 1; 
                blendValue=saturate(blendValue)*0.5;
                Unity_Blend_HardLight_float4(baseColor,customLight, blendValue, finalRGB);
                blendValue= FresnelEffect(IN.normal, viewDir, _Freshnel);
                blendValue=saturate(blendValue);
               resultReflection=resultReflection*_PowerReflectionIntensity;
               Unity_Blend_HardLight_float4(finalRGB,resultReflection, blendValue * _ReflectionIntensity, finalRGB); //blend base color vs reflection
              
                return half4(finalRGB,1);
                

            }
            ENDHLSL
        }
    }
}

