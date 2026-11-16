-- Auras que têm VFX próprio montado no cliente (malhas 3D + movimento procedural).
-- O servidor só replica QUAL aura está ativa (atributo "AuraVfx" no personagem); cada cliente
-- monta o efeito localmente. Para essas, o efeito antigo de partículas do servidor não é criado.
-- Essas auras ainda não estão no catálogo de sorteio: por enquanto só existem como prévia no Studio.
return {
	gear5 = true,
	-- família Naruto (Mundo/Auras/Caudas.luau)
	naruto_2 = true,
	naruto_3 = true,
	naruto_4 = true,
	naruto_5 = true,
	naruto_6 = true,
	naruto_7 = true,
	naruto_8 = true,
	naruto_9 = true,
	naruto_seis = true,
	-- Monarca das Sombras (Mundo/Auras/Monarca.luau)
	monarca = true,
} :: { [string]: boolean }
