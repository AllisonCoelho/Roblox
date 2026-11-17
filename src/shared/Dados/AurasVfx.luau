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
	-- Auras originais v2, lote inicial (Mundo/Auras/Originais): SÓ prévia, fora do sorteio atual.
	-- Sem ReplicatedStorage.AurasOriginais.<id> (importado no Studio) o cliente não monta nada.
	centelha_do_nexo = true,
	gelo_de_neon = true,
	prisma_partilhado = true,
	arquivista_espectral = true,
	coracao_de_fenix = true,
	leviata_astral = true,
	soberania_do_vazio = true,
} :: { [string]: boolean }
