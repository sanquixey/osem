class Event < ActiveRecord::Base
  include ActiveRecord::Transitions
  has_paper_trail
  attr_accessible :title, :subtitle, :abstract, :description, :event_type_id, :people_attributes, :person,
                  :proposal_additional_speakers, :track_id
  acts_as_commentable

  has_many :event_people, :dependent => :destroy
  has_many :event_attachments, :dependent => :destroy
  has_many :people, :through => :event_people
  belongs_to :event_type

  belongs_to :track
  belongs_to :room
  belongs_to :conference

  accepts_nested_attributes_for :event_people
  accepts_nested_attributes_for :event_attachments, :allow_destroy => true, :reject_if => :all_blank
  accepts_nested_attributes_for :people
  before_create :generate_guid
  validate :abstract_limit

  state_machine :initial => :new do
    state :new
    state :review
    state :withdrawn
    state :accepted
    state :unconfirmed
    state :confirmed
    state :canceled
    state :rejected

    event :start_review do
      transitions :to => :review, :from => [:new, :rejected]
    end
    event :withdraw do
      transitions :to => :withdrawn, :from => [:new, :review, :unconfirmed]
    end
    event :accept do
      transitions :to => :unconfirmed, :from => [:new, :review], :on_transition => :process_acceptance
    end
    event :unconfirm do
      transitions :to => :review, :from=>[:confirmed]
    end
    event :confirm do
      transitions :to => :confirmed, :from => :unconfirmed
    end
    event :cancel do
      transitions :to => :canceled, :from => [:unconfirmed, :confirmed]
    end
    event :reject do
      transitions :to => :rejected, :from => [:new, :review], :on_transition => :process_rejection
    end
  end

  def submitter
    result = self.event_people.where(:event_role => "submitter").first
    if !result.nil?
      result.person
    else
      nil
    end
  end
  def as_json(options)
    json = super(options)

    if self.room.nil?
      json[:room_guid] = nil
    else
      json[:room_guid] = self.room.guid
    end

    if self.track.nil?
      json[:track_color]  = "#ffffff"
    else
      json[:track_color] = self.track.color;
    end
    if self.event_type.nil?
      json[:length] = 25
    else
      json[:length] = self.event_type.length
    end

    json
  end
  def transition_possible?(transition)
    self.class.state_machine.events_for(self.current_state).include?(transition)
  end

  def process_acceptance(options)
    #if options[:send_mail]
    #end

  end

  def public_state
    public_state = "Submitted"
    case self.state
      when "withdrawn"
        public_state = "Withdrawn"
      when "new", "review"
        public_state = "Review Pending"
      when "accepted", "unconfirmed"
        public_state = "Accepted (confirmation pending)"
      when "confirmed"
        public_state = "Confirmed"
      when "rejected"
        public_state = "Rejected"
      when "cancelled"
        public_state = "Cancelled"
    end
    public_state
  end
  def abstract_word_count
    if self.abstract.nil?
      0
    else
      self.abstract.split.size
    end
  end
  private

  def abstract_limit
    if self.abstract.split.size > 250
      errors.add(:abstract, "cannot have more than 250 words")
    end
  end

  def generate_guid
    begin
      guid = SecureRandom.urlsafe_base64
    end while self.class.where(:guid => guid).exists?
    self.guid = guid
  end

end