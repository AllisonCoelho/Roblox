-- Auras que têm VFX próprio montado no cliente (malhas 3D + movimento procedural).
-- O servidor só replica QUAL aura está ativa (atributo "AuraVfx" no personagem); cada cliente
-- monta o efeito localmente. Para essas, o efeito antigo de partículas do servidor não é criado.
-- Essas auras estão disponíveis como prévia no Studio e no painel de desenvolvimento.
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
	-- Senbonzakura (Mundo/Auras/Senbonzakura.luau): só prévia; NÃO está no sorteio (Dados/Auras.luau).
	-- Sem ReplicatedStorage.AuraAssets.Senbonzakura (importado no Studio) o cliente não monta nada.
	senbonzakura = true,
} :: { [string]: boolean }
