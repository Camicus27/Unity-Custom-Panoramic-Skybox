// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Modified by Camicus27 (https://forum.unity.com/members/camicus27.8907255/) (https://github.com/Camicus27)

Shader "Skybox/CustomPanoramic" {
Properties {
    _Tint ("Tint Color", Color) = (.5, .5, .5, .5)
    [Gamma] _Exposure ("Exposure", Range(0, 8)) = 1.0
    [NoScaleOffset] _MainTex ("Panoramic Texture2D (HDR)", 2D) = "white" {}
    [Enum(Yes, 0, No, 1)] _AutoRotate("Auto-Rotation", Float) = 0
    _Rotation ("Rotation", Range(0, 360)) = 0
    _ImageAngle ("Horizontal Angle", Range(0, 360)) = 180.0
    _VerticalSquishScale ("Vertical Squish Scale", Range(0, 10)) = 5.333333
    _YOffset ("Y-Offset", Range(0, 1.0)) = 0.45
}

SubShader {
    Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
    Cull Off ZWrite Off

    Pass {

        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 2.0

        #include "UnityCG.cginc"

        sampler2D _MainTex;
        float4 _MainTex_TexelSize;
        half4 _MainTex_HDR;
        half4 _Tint;
        half _Exposure;
        float _Rotation;
        float _ImageAngle;
        float _VerticalSquishScale;
        float _YOffset;
        int _AutoRotate;

        inline float2 ToRadialCoords(float3 coords)
        {
            float3 normalizedCoords = normalize(coords);
            float latitude = acos(normalizedCoords.y);
            float longitude = atan2(normalizedCoords.z, normalizedCoords.x);
            float2 sphereCoords = float2(longitude, latitude) * float2(0.5/UNITY_PI, 1.0/UNITY_PI);
            return float2(0.5,1.0) - sphereCoords;
        }

        float3 RotateAroundYInDegrees (float3 vertex, float degrees)
        {
            float alpha = degrees * UNITY_PI / 180.0;
            float sina, cosa;
            sincos(alpha, sina, cosa);
            float2x2 m = float2x2(cosa, -sina, sina, cosa);
            return float3(mul(m, vertex.xz), vertex.y).xzy;
        }

        struct appdata_t {
            float4 vertex : POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct v2f {
            float4 vertex : SV_POSITION;
            float3 texcoord : TEXCOORD0;
            float2 image180ScaleAndCutoff : TEXCOORD1;
            float4 layout3DScaleAndOffset : TEXCOORD2;
            UNITY_VERTEX_OUTPUT_STEREO
        };

        v2f vert (appdata_t v)
        {
            v2f o;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

            // Calculate constant horizontal scale and cutoff
            o.image180ScaleAndCutoff = float2(360.0 / _ImageAngle, _ImageAngle / 360.0);

            // Calculate vertical scale
            o.layout3DScaleAndOffset = float4(0,0,1,_VerticalSquishScale);

            // Calculate rotation
            if (_AutoRotate == 0)
                _Rotation = 360.0 - (_ImageAngle * 0.5) - (90 - _ImageAngle);
            float3 rotated = RotateAroundYInDegrees(v.vertex, _Rotation);

            o.vertex = UnityObjectToClipPos(rotated);
            o.texcoord = v.vertex.xyz;
            
            return o;
        }

        fixed4 frag (v2f i) : SV_Target
        {
            float2 tc = ToRadialCoords(i.texcoord);
            if (tc.x > i.image180ScaleAndCutoff[1])
                return half4(0,0,0,1);
            tc.x = fmod(tc.x * i.image180ScaleAndCutoff[0], 1);
            tc.y = fmod(tc.y - _YOffset, 1);
            tc = (tc + i.layout3DScaleAndOffset.xy) * i.layout3DScaleAndOffset.zw;

            half4 tex = tex2D (_MainTex, tc);
            half3 c = DecodeHDR (tex, _MainTex_HDR);
            c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
            c *= _Exposure;
            return half4(c, 1);
        }
        ENDCG
    }
}

Fallback Off

}