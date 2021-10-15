Shader "Custom/Car"
{
	Properties{
	_BaseColor("Color1",Color)= (1,1,1,1)
		
	}

	SubShader{
  		 Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

		   pass{
			
			//URP chi chay dc hlsl
			   	HLSLPROGRAM
				   //khai bao vertex vs frag
					#pragma vertex vert
					#pragma fragment frag
					#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
					
					struct InputVertex{
							float4 pos:POSITION;
							half3 normal:NORMAL;
						
					};

					struct OutVertex{
							float4 pos:SV_POSITION;
					};


					OutVertex vert(InputVertex i){
						OutVertex o;
						o.pos= TransformObjectToHClip(i.pos.xyz);
						return o;
					}

					half4 frag():SV_TARGET {
						half4 o;
						o=half4(0.5,1,1,1);
						return o;
					}

				ENDHLSL
		   }
	}
}
