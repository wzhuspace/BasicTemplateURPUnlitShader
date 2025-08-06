Shader "Wen/CustomPBR"
{
    Properties
    {
        _Albedo("Albedo Map", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _MetalnessMap("Metallic Map", 2D) = "black" {}
        _RoughnessMap("Roughness Map", 2D) = "black" {}
        _OcclusionMap("Occlusion Map", 2D) = "white" {}
        
        [Toggle(_EMISSION)] _EnableEmission("Enable Emission", Float) = 0
        [NoScaleOffset] _EmissionMap("EmissionMap Map", 2D) = "black" {}
        [HDR] _EmissionColor("Emission Color", Color) = (0.0, 0.0, 0.0)

        _IBLMap("IBL Map", 2D) = "white" {}

        _AlbedoColor("Albedo Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _NormalScale("Normal Scale", Float) = 1.0
        _Roughness("Roughness", Range(0, 2)) = 0
        _Metalness("Metallic", Range(0, 1)) = 0
        _Occlusion("Occlusion", Range(0, 1)) = 0
        
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
            "Queue"= "Geometry"
        }

        // ------------------------------------ MAIN PASS------------------------------------
        Pass
        {
            Tags
            { "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Assets/# My Folder/PBR/PBRLib.cginc"

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            // ------------------------------------ Constant ------------------------------------
            #define EPSILON 1e-6

            // ------------------------------------ Universal Render Pipeline keywords------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma shader_feature_local_fragment _EMISSION
            
            // ------------------------------------ TEXTURE ------------------------------------
            TEXTURE2D(_Albedo); SAMPLER(sampler_Albedo);
            TEXTURE2D(_EmissionMap); 
            TEXTURE2D(_NormalMap); 
            TEXTURE2D(_MetalnessMap); 
            TEXTURE2D(_RoughnessMap); 
            TEXTURE2D(_OcclusionMap); 
            TEXTURE2D(_IBLMap); 

            // ------------------------------------ FLOAT ------------------------------------
            CBUFFER_START(UnityPerMaterial)
                half4 _Albedo_ST;
                half4 _AlbedoColor;
                half3 _EmissionColor;
                half _NormalScale;
                half _Roughness;
                half _Metalness;
                half _Occlusion;
                half _Cutoff;
            CBUFFER_END
            
            // ------------------------------------ Read Data from Geometry ------------------------------------
            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            // ----------------------------------- Pass the data from Vertex Shader to Fragment Shader------------------------------------
            struct v2f
            {
                float2 uv         :     TEXCOORD0;
                float3 positionWS :     TEXCOORD1;
                float3 normalWS    :     TEXCOORD2;
                float4 tangentWS :       TEXCOORD3;
                float4 positionCS :     SV_POSITION;    
            };

            // ------------------------------------ VERTEX SHADER ------------------------------------
            v2f vert(appdata input)
            {
                v2f output = (v2f)0; // Initialize output to zero
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.uv = input.texcoord;

                output.normalWS = normalInput.normalWS;
                half sign = input.tangentOS.w * GetOddNegativeScale();
                half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
                output.tangentWS = tangentWS; 

                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS; // Clip space position
                
                return output;
            }

            // ------------------------------------ FRAGMENT SHADER ------------------------------------
            float4 frag(v2f input): SV_Target
            {
                //World Position
                float3 worldPos = input.positionWS;

                // --------------- INPUTS: VECTOR ----------------
                float3 viewDir = GetWorldSpaceNormalizeViewDir(input.positionWS); //V
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction); //L
                float3 halfwayVector = normalize(lightDir + viewDir); // H:halfway Vector

                // Normal 
                half3 worldNormal = normalize(input.normalWS);
                half3 worldTangent = normalize(input.tangentWS.xyz);
                half3 worldBiNormal = normalize(cross(worldNormal, worldTangent)) * input.tangentWS.w;
                half3x3 TBN = half3x3(worldTangent, worldBiNormal, worldNormal);
                //-------------------------------------------------------

                // --------------- INPUTS: TEXTURE ----------------
                // UV
                float2 uv = input.uv;
                
                // Albedo 
                float3 albedo = SAMPLE_TEXTURE2D(_Albedo, sampler_Albedo, uv).rgb * _AlbedoColor.rgb;
                
                // Albedo Alpha
                float alpha = SAMPLE_TEXTURE2D(_Albedo, sampler_Albedo, uv).a;
                #if defined(_ALPHATEST_ON)
                    clip(alpha - _Cutoff);
                #endif
                
                // Emission
                float3 emission = float3(0.0, 0.0, 0.0);
                #ifdef _EMISSION
                        emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_Albedo, uv).rgb * _EmissionColor.rgb;
                #endif
 
                // Convert Normal Map and GET Normal in World Space
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_Albedo, uv), _NormalScale);
                worldNormal = normalize(mul(normalTS, TBN)); // Transform normal from tangent space to world space
                
                // Roughness
                float roughness = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_Albedo, uv).r * _Roughness;
                roughness = max(0.04, min(0.99, roughness)); // Clamp roughness to avoid division by zero in NDF calculation
                // Metallic
                float metallic = SAMPLE_TEXTURE2D(_MetalnessMap, sampler_Albedo, uv).r;
                metallic = saturate(metallic * _Metalness);
                // Occlusion
                float occlusion = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_Albedo, uv).r;
                occlusion = lerp(1.0, occlusion, _Occlusion); 
                
                // -------------------- BRDF --------------------------
                // Part 1: Normal Distribution Function (NDF)
                float NDF = DistributionGGX(worldNormal, halfwayVector, roughness);
                
                // Part 2: Geometry Function
                float GS = GeometrySmith(worldNormal, viewDir, lightDir, roughness);
                
                // Part 3: Fresnel Function
                float HdotV = max(dot(halfwayVector, viewDir), EPSILON); // max(EPSILON) makes sure the output is not negative
                
                // f0 lerp between 0.04 and albedo color based on metallic value
                float3 F0 = lerp(float3(0.04, 0.04, 0.04), albedo, metallic);
                float3 F = FresnelSchlick(HdotV, F0);
                
                // ----- Part 4: Final BRDF Calculation -----
                float NdotV = max(dot(worldNormal, viewDir), EPSILON);
                float NdotL = max(dot(worldNormal, lightDir), EPSILON);

                float3 nominator = NDF * GS * F;
                float denominator = 4.0 * max(NdotV * NdotL, EPSILON) + 0.001;
                // Adding a small value 0.001 to avoid division by zero
                float3 specularBRDF = nominator / denominator;
    
                // --------------------- POST-PROCESS SCREEN OCCLUSION-------------------------------
                float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS); // for screen space ambient occlusion - post process
                #if defined(_SCREEN_SPACE_OCCLUSION)
                    AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(screenUV);
                    occlusion = min(occlusion,aoFactor.indirectAmbientOcclusion);
                #endif

                // -------------- PART 1 : Direct lighting calculation -------------- 
                float3 kS = F;
                float3 kD = (1 - kS) * (1 - metallic); // Diffuse term is affected by metallic value 
                float3 diffuse = albedo.rgb * kD; // * Note: diffuse NOT equal to albedo in metallic materials
                float3 radianceLo = _MainLightColor.rgb * NdotL; // 有效入射光能
                float shadow = mainLight.shadowAttenuation;
                float3 directLighting = (diffuse / PI + specularBRDF) * radianceLo * shadow;
                // ----------------------------------------------------

                // ------------- Additional Direct Lighting calculation -------------
                float3 additionalLights = float3(0.0, 0.0, 0.0);
                
                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                
                for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light additionalLight = GetAdditionalLight(lightIndex, worldPos);

                    // 按照directional light的步骤重新算一遍
                    half3 addLDir = additionalLight.direction;
                    half3 addlightColor = additionalLight.color;
                    half3 addH = normalize(addLDir + viewDir);
                    half addShadow  = additionalLight.shadowAttenuation * additionalLight.distanceAttenuation;
                    float addNDF = DistributionGGX(worldNormal, addH, roughness);
                    float addGS = GeometrySmith(worldNormal, viewDir, addLDir, roughness);
                    float addHdotV = max(dot(addH, viewDir), EPSILON);
                    float3 addF0 = lerp(float3(0.04, 0.04, 0.04), albedo, metallic);
                    float3 addF = FresnelSchlick(addHdotV, addF0);
                    float addNdotV = max(dot(worldNormal, viewDir), EPSILON);
                    float addNdotL = max(dot(worldNormal, addLDir), EPSILON);
                    float3 addNominator = addNDF * addGS * addF;
                    float addDenominator = 4.0 * max(addNdotV * addNdotL, EPSILON) + 0.001; // Avoid division by zero
                    
                    float3 addSpecularBRDF = addNominator / addDenominator;
                    float3 addRadianceLo = addlightColor * max(addNdotL, 0.0); 

                    float3 addKs = addF;
                    float3 addKd = (1 - addKs) * (1 - metallic); // Diffuse term is affected by metallic value
                    float3 addDiffuse = albedo.rgb * addKd; // * Note: diffuse NOT equal to albedo in metallic materials
                    
                    additionalLights += (addDiffuse/ PI + addSpecularBRDF) * addRadianceLo * addShadow;
                }
                #endif
                
                directLighting = directLighting + additionalLights;
                
                // ---------------  PART 2: Indirect lighting calculation --------------
                // ----- Diffuse irradiance 球谐函数中采样环境光照 -> 辐照度图作为光照的间接漫反射部分 -----
                // Normal Based -> Normal faces upwards of the surface reflect the environment light color, vice versa
                float3 diffuseIrradiance = SampleSH(worldNormal) * occlusion * diffuse; //Ambient Diffuse Light

                // ----- Specular IBL: Image Based Lightning-----
                float mipLevel = roughness * 6.0; // Roughness to mip level

                float3 R = reflect(-viewDir, worldNormal); // Reflect view direction around normal 反射方向
                // 在URP中，environment cube采样函数会自动处理HDR解码
                float3 envSample = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, R, mipLevel).rgb;
                // Sample environment map
                float3 F_IBL = FresnelSchlickRoughness(NdotV, F0, roughness); // Indirect Fresnel 间接光菲涅尔
                float2 envBRDF = SAMPLE_TEXTURE2D(_IBLMap, sampler_Albedo, float2(NdotV, roughness)).rg;
                // Ambient Specular Light
                float3 ambientSpecular = envSample * (F_IBL * envBRDF.x + envBRDF.y) * occlusion;
                // ----------------------------------------------------

                // -------------------- FINAL COLOR --------------------------
                float4 finalColor = float4((directLighting + diffuseIrradiance + ambientSpecular + emission), 1.0);

                return finalColor; // Return the final color
            }
            
            ENDHLSL
        }


        // ------------------------------------ Shadow Caster PASS------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        // ------------------------------------ Depth PASS------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // ------------------------------------ Depth Normal PASS------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}