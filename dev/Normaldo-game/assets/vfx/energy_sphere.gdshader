shader_type canvas_item;
render_mode blend_mix;

// ── Энергетическая сфера ─────────────────────────────────────────────────────
// Портирован ВИД портала из присланного набора BinbunVFX. Сам набор в проекте не
// работает: все его шейдеры `shader_type spatial`, сцена собрана из Node3D и
// GPUParticles3D, а игра двумерная и собрана на GL Compatibility без буфера
// трафарета. Но математика, которая делает портал порталом, к третьему
// измерению отношения не имеет — это слои полярного шума, наложенные друг на
// друга с затуханием вглубь. Она и перенесена.
//
// Что пришлось заменить и почему:
//   • ПАРАЛЛАКС. В оригинале слои сдвигаются по вектору взгляда (NORMAL,
//     TANGENT, VIEW). В 2D камеры нет и взгляда нет; вместо сдвига слои
//     РАЗЖИМАЮТСЯ от центра — ощущение глубины то же, а считать нечего.
//   • ФОРМА. Оригинал берёт радиальный градиент текстурой. Здесь он считается
//     из UV одной строкой: текстура ради круга — это лишний файл и лишняя
//     выборка.
//   • ИСКАЖЕНИЕ ЭКРАНА за порталом убрано: в 2D для него нужен BackBufferCopy,
//     то есть копия кадра на каждый резист. Сфера не окно в другой мир, ей
//     нечего показывать за собой.
//   • EMISSION убран — в canvas_item его нет; яркость даёт сам цвет.

uniform vec4 primary_color   : source_color = vec4(0.35, 0.78, 1.00, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.04, 0.13, 0.38, 1.0);
uniform sampler2D noise_texture : repeat_enable;

// Насколько сфера «открыта»: 0 — точка в центре, 1 — полный шар. По ней и
// делается появление и спад.
uniform float open_amount : hint_range(0.0, 1.0, 0.01) = 1.0;

uniform float density       : hint_range(0.0, 1.0, 0.01) = 0.40;
uniform float edge_softness : hint_range(0.0, 1.0, 0.01) = 0.50;
uniform float shrink_amount : hint_range(0.0, 1.0, 0.01) = 0.50;
uniform float shape_warp    : hint_range(0.0, 1.0, 0.01) = 0.14;

uniform int   layers       : hint_range(1, 16, 1) = 8;
uniform float depth_amount = 0.55;
uniform float fade_amount  : hint_range(0.0, 16.0, 0.01) = 1.0;

uniform float speed_scale   = 1.0;
uniform float spin_motion   = 0.5;
uniform float inward_motion = 1.0;
uniform float base_motion   = 0.2;

// Ободок по краю: именно он превращает диск в ШАР. Без него сфера читается как
// плоское пятно шума.
uniform float rim_boost : hint_range(0.0, 4.0, 0.01) = 1.7;
uniform float rim_from  : hint_range(0.0, 1.0, 0.01) = 0.72;
// Плотность нутра. Ободок при этом остаётся полным — он и есть край шара.
uniform float inner_alpha : hint_range(0.0, 1.0, 0.01) = 0.42;

vec2 to_polar(vec2 uv) {
	float radius = length(uv);
	float angle  = atan(uv.x, uv.y);
	return vec2(angle / 2.0, radius) / PI;
}

float blend_overlay(float a, float b) {
	float limit = step(0.5, a);
	return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), limit);
}

// 0 в центре, 1 на краю сферы, БОЛЬШЕ ЕДИНИЦЫ — снаружи. Ничего не зажимаем, и
// это не мелочь: раньше здесь стояло два clamp, и из-за них вокруг головы
// вспыхивал голубой КВАДРАТ.
//
// Как он получался. Углы квадрата спрайта дальше от центра, чем его края:
// 1.41 против 1.0. Зажатое в единицу расстояние делало их неотличимыми от
// самого края сферы. Пока `open_amount` не больше единицы, это сходило с рук —
// край всё равно оказывался ровно на границе и гасился. Но появление идёт через
// TRANS_BACK, а он НАМЕРЕННО ПЕРЕСКАКИВАЕТ цель: `open_amount` на мгновение
// уходит примерно к 1.1. Деление на него опускало «расстояние» углов внутрь
// видимой полосы — и светиться начинал весь квадрат разом, вместе со сферой.
//
// Без зажима углы честно остаются снаружи при любом перескоке: 1.41 / 1.1 всё
// ещё больше единицы. Дальше по коду результат везде проходит через smoothstep
// и clamp, так что значения больше единицы никому не мешают.
float sample_shape(vec2 uv, float depth) {
	float dist = length(uv - vec2(0.5)) * 2.0;
	return dist / max(open_amount - depth * shrink_amount, 0.001);
}

float sample_noise(vec2 uv, float depth, float scale) {
	uv = uv * (2.0 * scale) - (1.0 * scale);
	vec2 motion = vec2(TIME) * (depth + base_motion)
		* vec2(spin_motion, inward_motion) * speed_scale;
	uv = (to_polar(uv) + vec2(depth, 0.0)) + motion;
	uv.x *= scale;
	return texture(noise_texture, uv).r;
}

void fragment() {
	float value = 0.0;
	for (int i = 0; i < layers; i++) {
		float t     = float(i) / float(layers);
		float depth = t * depth_amount;

		// Слои разжимаются от центра — тот самый заменённый параллакс.
		vec2 luv = (UV - vec2(0.5)) * (1.0 + depth * 0.55) + vec2(0.5);

		float circle = sample_shape(luv, t);
		circle = clamp((circle - (0.5 - density)) / (1.5 - density), 0.0, 1.0);

		float nm = sample_noise(luv, t, 2.0);
		float n  = sample_noise(luv * (1.0 - nm * shape_warp), t, 1.0);

		float shaped = blend_overlay(circle, n);
		float e_min  = mix(0.4, 0.8, 1.0 - edge_softness);
		float e_max  = mix(1.0, 0.8, 1.0 - edge_softness);
		shaped = smoothstep(e_min, e_max, shaped);

		value = max(value, shaped * pow(1.0 - t, fade_amount));
	}

	float shape = sample_shape(UV, 0.0);

	vec3 col = mix(secondary_color.rgb, primary_color.rgb, value);
	float rim = smoothstep(rim_from, 0.98, shape) * (1.0 - smoothstep(0.98, 1.02, shape));
	col = mix(col, clamp(primary_color.rgb * rim_boost, vec3(0.0), vec3(1.0)), rim);

	// Сфера — ОБОЛОЧКА, а не заливка. Нутро держим заметно прозрачнее ободка:
	// на полной плотности шар закрашивал голову молоком, и вместо «меня
	// прикрыло» читалось «мне что-то залепило экран». Игрок обязан видеть
	// сквозь неё и себя, и то, обо что он не ударился.
	float inside = 1.0 - smoothstep(0.94, 1.0, shape);
	float alpha  = inside * max(value * inner_alpha, rim);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0) * open_amount);
}
