-- Auras que têm VFX próprio montado no cliente (malhas 3D + movimento procedural).
-- O servidor só replica QUAL aura está ativa (atributo "AuraVfx" no personagem); cada cliente
-- monta o efeito localmente. Para essas, o efeito antigo de partículas do servidor não é criado.
-- "gear5" ainda não está no catálogo de sorteio: por enquanto só existe como prévia no Studio.
return {
	gear5 = true,
} :: { [string]: boolean }
