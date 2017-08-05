Discord = require 'discord.js'
MirrorPool = require 'mirror-pool'
waitUntil = (require 'wait-until-promise').default

class _DiscordMirror extends MirrorPool.Mirror
	constructor: (@channel) ->
		super

	inputMatches: (discordMessage) ->
		discordMessage.channel.id is @channel.id

	inputToMessage: (discordMessage) ->
		Promise.resolve {
			sender: (@findName discordMessage),
			text: (@cleanCustomEmoji discordMessage.cleanContent),
		}

	findName: (discordMessage) ->
		author = discordMessage.author
		if @channel.guild
			member = @channel.guild.members.get author.id
			if member and member.nickname
				member.nickname
			else
				author.username
		else
			author.username

	cleanCustomEmoji: (messageText) ->
		messageText.replace /<:(\w+):\d+>/g, ':$1:'

	sendMirrored: (message) ->
		if typeof @channel.send is 'function'
			promise = @channel.send @formatMessage message
			promise.catch console.error

	formatMessage: (message) ->
		message.sender + ': ' + message.text

module.exports = class DiscordBot extends MirrorPool.Bot
	constructor: (@options = {}) ->
		super
		@_client = new Discord.Client
		@_client.on 'message', (message) =>
			if message.author.id isnt @_client.user.id
				@mirrorInput message
		@_client.on 'ready', =>
			@_ready = true

		loginPromise = @_client.login @options.token
		timeout = @options.timeout or 3000
		@_readyPromise = loginPromise.then =>
			waitUntil (=> @_ready), timeout, 100

	createMirrorCore: (options = {}) ->
		@_readyPromise.then =>
			serverId = options.server or @options.defaultServer
			if not serverId
				throw new Error 'Need to specifiy Discord server'

			if not options.channel
				throw new Error 'Need a channel name or ID'

			server = @_client.guilds.get serverId
			if not server
				throw new Error 'Not a member of the given Discord server'

			if options.channel.charAt 0 is '#'
				channelName = options.channel.slice 1
				channel = server.channels.find (channel) ->
					channel.type is 'text' \
					and channel.name is channelName
			else
				channel = server.channels.find (channel) ->
					channel.id is options.channel

			if not channel
				throw new Error 'Channel not found on the Discord server'

			new _DiscordMirror channel
