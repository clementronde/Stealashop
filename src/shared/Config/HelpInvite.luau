--!strict
-- Conseil après une capture (vague 73, a256 ; liaison L-242 point 6, écran UI_HelpInvite de Clément) : lu par
-- Controllers/HelpInviteController (client). Après une capture par un vigile ou la police (remote CatchScene, la
-- scène finie), si le joueur n'avait pas la force (Damage) ou la vitesse (ShownSpeed) conseillées du magasin le plus
-- proche (Shared/AdvicePanel.levels : pas « vert »), la carte propose d'inviter un ami. Aucune règle de jeu.
-- Textes de Clément (L-242) ; le reste : V0 proposés, absents du doc.

local DeepFreeze = require(script.Parent.DeepFreeze)

local HelpInvite = {
	Enabled = true,
	Screen = "UI_HelpInvite",
	Card = "Card",
	Message = "Card.Message",
	InviteButton = "Card.InviteButton",
	CloseButton = "Card.CloseButton",
	-- L-242 : le début en jaune (RichText).
	StrengthText = '<font color="#FFD23A">Not strong enough?</font> Invite a friend to help you rob this store!',
	SpeedText = '<font color="#FFD23A">Not fast enough?</font> Invite a friend to help you rob this store!',
	-- V0 : les deux manquent → le conseil de force (on ne passe pas la vitrine sans elle).
	Delay = 0.3, -- V0 : s après la fin de la scène de capture (CatchSceneController) avant la carte
	MaxWait = 8, -- V0 : s au plus à attendre la fin de la scène
	Duration = 10, -- V0 : la carte s'éteint seule après ces secondes (0 = jamais)
	Cooldown = 60, -- V0 : s au moins entre deux cartes
	-- Décision de Cantin du 18/11 (B5, « la nuit devrait mettre le message quand meme ») : le conseil aussi après une
	-- arrestation de nuit (avant : false, V0).
	Night = true,
}

export type HelpInvite = typeof(HelpInvite)

return DeepFreeze(HelpInvite)
