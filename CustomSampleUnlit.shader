Shader "Custom/BasicUnlit"
{
    // These properties are exposed to the inspector
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
        _TintColor("Tint Color", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }
        
        // ----------- unlit main pass ----------
        Pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Sample the texture
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            // We can use the CBUFFER_START(UnityPerMaterial) to define the Keyword mainly for SRP Bactching
            // We dont need to defind texture here.
            CBUFFER_START(UnityPerMaterial)
                half4 _MainTex_ST;
                half4 _TintColor;
            CBUFFER_END

            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in the vertex shader.
            struct MeshData
            {
                // The positionOS variable contains the vertex positions in object space.
                float4 positionOS : POSITION;
                // Mesh UV
                float2 texCord  : TEXCOORD0;
            };

            struct Vertex2Fragment
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            // The vertex shader definition with properties defined in the Varyings structure.
            // The type of the vert function must match the type (struct) that it returns.
            Vertex2Fragment vert(MeshData IN)
            {
                // Declaring the output object (OUT) with the Varyings struct. Initialize the output to 0 first.
                Vertex2Fragment OUT = (Vertex2Fragment)0;
                // The TransformObjectToHClip function transforms vertex positions from object space to homogenous clip space.
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.uv = IN.texCord;
                
                // Returning the output.
                return OUT;
            }

            // The fragment shader definition.
            half4 frag(Vertex2Fragment input) : SV_Target
            {
                float2 uv = input.uv;
                float3 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb * _TintColor.rgb;
                float4 finalColor = float4(mainTex, 1);
                return finalColor;
            }
            ENDHLSL
        }
        
        // ---------- Depth Pass --------
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

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // ---------- Depth Normal Pass--------
        Pass
        {
            Name "DepthNormalsOnly"
            Tags
            {
                "LightMode" = "DepthNormalsOnly"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT // forward-only variant
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitDepthNormalsPass.hlsl"
            ENDHLSL
        }
        
    }
}