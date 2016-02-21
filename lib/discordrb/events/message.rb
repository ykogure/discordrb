require 'discordrb/events/generic'

module Discordrb::Events
  # Event raised when a text message is sent to a channel
  class MessageEvent
    attr_reader :message, :saved_message

    delegate :author, :channel, :content, :timestamp, to: :message
    delegate :server, to: :channel

    def initialize(message, bot)
      @bot = bot
      @message = message
      @saved_message = ''
    end

    def send_message(content)
      @message.channel.send_message(content)
    end

    def from_bot?
      @message.user.id == @bot.bot_user.id
    end

    def <<(message)
      @saved_message += "#{message}\n"
      nil
    end

    alias_method :user, :author
    alias_method :text, :content
    alias_method :send, :send_message
    alias_method :respond, :send_message
  end

  # Event handler for MessageEvent
  class MessageEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? MessageEvent

      [
        matches_all(@attributes[:starting_with] || @attributes[:start_with], event.content) do |a, e|
          if a.is_a? String
            e.start_with? a
          elsif a.is_a? Regexp
            (e =~ a) == 0
          end
        end,
        matches_all(@attributes[:ending_with] || @attributes[:end_with], event.content) do |a, e|
          if a.is_a? String
            e.end_with? a
          elsif a.is_a? Regexp
            a.match(e) ? e.end_with?(a.match(e)[-1]) : false
          end
        end,
        matches_all(@attributes[:containing] || @attributes[:contains], event.content) do |a, e|
          if a.is_a? String
            e.include? a
          elsif a.is_a? Regexp
            (e =~ a)
          end
        end,
        matches_all(@attributes[:in], event.channel) do |a, e|
          if a.is_a? String
            # Make sure to remove the "#" from channel names in case it was specified
            a.delete('#') == e.name
          elsif a.is_a? Fixnum
            a == e.id
          else
            a == e
          end
        end,
        matches_all(@attributes[:from], event.author) do |a, e|
          if a.is_a? String
            a == e.name
          elsif a.is_a? Fixnum
            a == e.id
          elsif a == :bot
            e.bot?
          else
            a == e
          end
        end,
        matches_all(@attributes[:with_text] || @attributes[:content], event.content) do |a, e|
          if a.is_a? String
            e == a
          elsif a.is_a? Regexp
            a.match(e) ? (e == (a.match(e)[0])) : false
          end
        end,
        matches_all(@attributes[:after], event.timestamp) { |a, e| a > e },
        matches_all(@attributes[:before], event.timestamp) { |a, e| a < e },
        matches_all(@attributes[:private], event.channel.private?) { |a, e| !e == !a }
      ].reduce(true, &:&)
    end

    # @see EventHandler#after_call
    def after_call(event)
      event.send_message(event.saved_message)
    end
  end

  class MentionEvent < MessageEvent; end
  class MentionEventHandler < MessageEventHandler; end

  class PrivateMessageEvent < MessageEvent; end
  class PrivateMessageEventHandler < MessageEventHandler; end

  # A subset of MessageEvent that only contains a message ID and a channel
  class MessageIDEvent
    # @return [Integer] the ID associated with this event
    attr_reader :id

    # @return [Channel] the channel in which this event occurred
    attr_reader :channel

    # @!visibility private
    def initialize(data, bot)
      @id = data['id'].to_i
      @channel = bot.channel(data['channel_id'].to_i)
      @bot = bot
    end
  end

  # Event handler for {MessageIDEvent}
  class MessageIDEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? MessageIDEvent

      [
        matches_all(@attributes[:id], event.id) do |a, e|
          a.resolve_id == e.resolve_id
        end,
        matches_all(@attributes[:in], event.channel) do |a, e|
          if a.is_a? String
            # Make sure to remove the "#" from channel names in case it was specified
            a.delete('#') == e.name
          elsif a.is_a? Integer
            a == e.id
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end

  # Raised when a message is edited
  # @see Discordrb::EventContainer#message_edit
  class MessageEditEvent < MessageIDEvent; end
  class MessageEditEventHandler < MessageIDEventHandler; end

  # Raised when a message is deleted
  # @see Discordrb::EventContainer#message_delete
  class MessageDeleteEvent < MessageIDEvent; end
  class MessageDeleteEventHandler < MessageIDEventHandler; end
end
