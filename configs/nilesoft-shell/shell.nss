// 🌸 Nilesoft Shell - Catppuccin Mocha Context Menu Config
// Setup for 6e5tz Windows Desktop Rice

settings
{
	priority = 1
	exclude.where = !process.is_explorer
	show.delay = 100
	modify.mousenav = true
	terminal = "wt"
}

theme
{
	name = "catppuccin-mocha"
	dark = true
	view = view.medium
	background
	{
		color = #1e1e2e
		opacity = 88
		effect = 2
	}
	border
	{
		size = 1
		color = #89b4fa
		radius = 8
	}
	shadow
	{
		size = 8
		color = #11111b
		opacity = 60
	}
	item
	{
		text
		{
			normal = #cdd6f4
			select = #ffffff
			disabled = #6c7086
		}
		back
		{
			select = #313244
		}
		border
		{
			radius = 6
		}
	}
	separator
	{
		color = #45475a
	}
}

// Quick Rice Actions on Desktop & File Explorer
menu(type='desktop' separator='after' title='Desktop Rice' image=\uE149)
{
	item(title='Open Terminal (pwsh)' image=\uE193 cmd='wt')
	item(title='Run Fastfetch' image=\uE14C cmd='wt' args='-w 0 pwsh -NoExit -Command "ff"')
	item(title='Open Hardware Monitor (Btop)' image=\uE1C3 cmd='wt' args='-w 0 pwsh -NoExit -Command "btop"')
	item(title='Screensaver Pipes' image=\uE1CE cmd='wt' args='-w 0 pwsh -NoExit -Command "pipes"')
	separator
	item(title='Reload GlazeWM' image=\uE107 cmd='glazewm' args='command reload-config')
	item(title='Restart Explorer' image=\uE117 cmd='powershell' args='-NoProfile -Command "Stop-Process -Name explorer -Force"')
}
