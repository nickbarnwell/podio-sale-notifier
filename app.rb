# encoding: UTF-8
require 'rubygems'
require 'sinatra'
require 'podio'
require 'yaml'
require 'win32/sound'
include Win32

helpers do
	def conf(key)
		config = YAML::load(File.open('config.yml'))
		config[key]
	end
	#Casper should probably make this not suck
	def podio
		Podio.configure do |config|
		  config.api_url = "https://api.podio.com"
		  config.api_key = conf('api_key')
		  config.api_secret = conf('api_secret')
		  config.debug = true
		end
		Podio.client ||= Podio::Client.new
		Podio.client.get_access_token(conf('login'), conf('password'))
		Podio
	end
end

def validate_hook(hook_id, code)
	resp = podio::Hook.validate(hook_id, code)
	status 200
end

def is_sale?(item_id)
	item = podio::Item.find(item_id)
	rev = item['current_revision']['revision']
	diff = podio::Item.revision_difference(item_id, rev, rev-1)
	diff.each { |change|
		if change['label'].eql? "Lead Status"
			case change['to'][0]['value']
			when "Paying Customer"
				change = 1
			when "Paying Customer / Online"
				change = 2
			else
				change = false
			end
		end
	return change
	}
	
end

post '/podio' do
	case params[:type]
		when "hook.verify"
			validate_hook(19, params[:code])
		when "item.update"
			unless is_sale?(params[:item_id]) == false
				puts "We made a sale!"
				puts File.join(Dir.pwd, conf('online_sound'))
				Sound.play(File.join(Dir.pwd, conf('online_sound')))
			end
			status 200
		else
			halt 500
	end
end

not_found do
	status 404
	'That page wasn\'t found, sorry.'
end

error do
	status 500
	'Something has gone wrong, we\'re probably looking into it'
end