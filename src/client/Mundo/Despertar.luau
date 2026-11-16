-- Diretor do giro: decide qual encenação tocar para o resultado que o SERVIDOR já sorteou.
-- Não calcula chance nem resultado; só escolhe intensidade, câmera e efeitos conforme a
-- raridade real da aura e as preferências de acessibilidade do jogador.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Camera = require(script.Parent.Camera)
local Ritual = require(script.Parent.Ritual)
local Sons = require(script.Parent.Sons)

local Despertar = {}

export type Preferencias = {
	sons: boolean,
	animacoes: boolean, -- false = sem ritual nem câmera: o resultado aparece na hora
	movimentoReduzido: boolean,
	qualidadeBaixa: boolean,
	ocultarEfeitosAlheios: boolean,
	pularRepetidas: boolean,
}

-- Lê as preferências do estado do jogador (com padrões seguros enquanto ele carrega)
function Despertar.preferencias(configuracoes: { [string]: boolean }?): Preferencias
	local c = configuracoes or {}
	return {
		sons = c.sons ~= false,
		animacoes = c.animacoes ~= false,
		movimentoReduzido = c.movimentoReduzido == true,
		qualidadeBaixa = c.qualidadeBaixa == true,
		ocultarEfeitosAlheios = c.ocultarEfeitosAlheios == true,
		pularRepetidas = c.pularRepetidas == true,
	}
end

-- Categoria de apresentação para quem girou
function Despertar.categoria(
	aura: Auras.Aura,
	repetida: boolean,
	prefs: Preferencias
): Apresentacao.Categoria
	if repetida and prefs.pularRepetidas then
		return Apresentacao.abreviada()
	end
	return Apresentacao.de(aura.chance)
end

-- O céu escurece por instantes (categoria Absoluta). Efeito local e curto.
local function escurecerCeu(cor: Color3, duracao: number)
	local efeito = Instance.new("ColorCorrectionEffect")
	efeito.Name = "CeuDespertar"
	efeito.Parent = Lighting
	local ida = TweenService:Create(efeito, TweenInfo.new(0.5), {
		Brightness = -0.22,
		TintColor = Color3.new(1, 1, 1):Lerp(cor, 0.3),
	})
	ida:Play()
	task.delay(duracao, function()
		local volta = TweenService:Create(efeito, TweenInfo.new(0.8), {
			Brightness = 0,
			TintColor = Color3.new(1, 1, 1),
		})
		volta:Play()
		volta.Completed:Wait()
		efeito:Destroy()
	end)
end

-- Encenação completa no personagem de quem girou. aoRevelar é chamado no instante da revelação
-- (ou imediatamente se o personagem não existir). Devolve se a câmera cinematográfica entrou.
function Despertar.proprio(
	aura: Auras.Aura,
	cat: Apresentacao.Categoria,
	prefs: Preferencias,
	aoRevelar: () -> ()
): boolean
	Sons.ligado = prefs.sons
	local personagem = Players.LocalPlayer.Character
	if not personagem then
		task.spawn(aoRevelar)
		return false
	end
	Ritual.tocar(personagem, aura, {
		categoria = cat,
		completo = true,
		qualidadeBaixa = prefs.qualidadeBaixa,
		movimentoReduzido = prefs.movimentoReduzido,
		aoRevelar = aoRevelar,
	})
	local cor = Color3.fromHex(Auras.Tiers[aura.tier].cor)
	local comCamera = cat.camera and not prefs.movimentoReduzido
	if comCamera then
		Camera.tocar(personagem, cat, cor)
	end
	return comCamera
end

-- Versão abreviada no personagem de OUTRO jogador: sem câmera, sem travar ninguém.
function Despertar.alheio(jogador: Player, aura: Auras.Aura, prefs: Preferencias)
	local cat = Apresentacao.de(aura.chance)
	if not cat.alheios or prefs.ocultarEfeitosAlheios or not prefs.animacoes then
		return
	end
	local personagem = jogador.Character
	if not personagem then
		return
	end
	Sons.ligado = prefs.sons
	Ritual.tocar(personagem, aura, {
		categoria = cat,
		completo = false,
		qualidadeBaixa = prefs.qualidadeBaixa,
		movimentoReduzido = prefs.movimentoReduzido, -- os outros também são vistos rasgando a fenda
		aoRevelar = nil,
	})
	if cat.ceu and not prefs.movimentoReduzido then
		escurecerCeu(Color3.fromHex(Auras.Tiers[aura.tier].cor), 1.5)
	end
end

-- Pula a cena de quem girou (câmera volta na hora; o ritual termina e revela)
function Despertar.pular()
	Camera.encerrar()
	local personagem = Players.LocalPlayer.Character
	if personagem then
		Ritual.cancelar(personagem)
	end
end

return Despertar
