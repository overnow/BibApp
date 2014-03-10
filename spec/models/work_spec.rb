
<!-- saved from url=(0106)https://raw.github.com/jstirnaman/BibApp/63a57d664a0d130fa78b939a9f025c2a3be70d17/spec/models/work_spec.rb -->
<html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><style type="text/css"></style></head><body><pre style="word-wrap: break-word; white-space: pre-wrap;">require File.dirname(__FILE__) + '/../spec_helper'

describe Work do

  it { should belong_to(:publication) }
  it { should belong_to(:publisher) }
  it { should have_many(:name_strings).through(:work_name_strings) }
  it { should have_many(:work_name_strings).dependent(:destroy) }
  it { should have_many(:people).through(:contributorships) }
  it { should have_many(:contributorships).dependent(:destroy) }
  it { should have_many(:keywords).through(:keywordings) }
  it { should have_many(:keywordings).dependent(:destroy) }
  it { should have_many(:taggings).dependent(:destroy) }
  it { should have_many(:tags).through(:taggings) }
  it { should have_many(:users).through(:taggings) }
  it { should have_many(:external_system_uris) }
  it { should have_many(:attachments) }
  it { should belong_to(:work_archive_state) }

  it_should_behave_like "a class generating sort_name"

  context "abstract and default methods" do
    it "should raise errors on subclass responsibility" do
      lambda { Work.contributor_role }.should raise_error
      lambda { Work.creator_role }.should raise_error
    end

    it "should return a default type_uri" do
      Factory.build(:abstract_work).type_uri.should be_nil
    end
  end

  context "should be able to return name information on creators" do

    def make_test_data(work_type)
      @work = Factory.create(work_type)
      @author_name_strings = 5.times.collect { Factory.create(:name_string) }
      @editor_name_strings = 5.times.collect { Factory.create(:name_string) }
      @author_name_strings.each { |ns| @work.work_name_strings.create(:role =&gt; @work.creator_role, :name_string =&gt; ns) }
      @editor_name_strings.each { |ns| @work.work_name_strings.create(:role =&gt; @work.contributor_role, :name_string =&gt; ns) }
    end

    it "returns for authors" do
      make_test_data(:generic)
      @work.authors.to_set.should == @author_name_strings.collect { |ns| {:name =&gt; ns.name, :id =&gt; ns.id} }.to_set
    end

    it "returns for editors" do
      make_test_data(:generic)
      @work.editors.to_set.should == @editor_name_strings.collect { |ns| {:name =&gt; ns.name, :id =&gt; ns.id} }.to_set
    end

    it "returns empty for editors if the author and editor roles are the same" do
      make_test_data(:patent)
      @work.editors.should == []
    end
  end

  context "should be able to return open_url kevs" do
    before(:each) do
      #to test the default implementation we need a work subclass that doesn't override open_url_kevs
      #Generic seems a safe choice, but if this test starts failing take that into consideration
      @work = Factory.create(:generic, :title_primary =&gt; 'WorkTitle', :publication_date_year =&gt; 2011, :publication_date_month =&gt; 3,
                             :publication_date_day =&gt; 4, :volume =&gt; '11', :issue =&gt; '9', :start_page =&gt; '211', :end_page =&gt; '310')
    end

    it "always returns a standard set" do
      kevs = @work.open_url_kevs
      kevs[:format].should == "&amp;rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Ajournal"
      kevs[:genre].should == "&amp;rft.genre=article"
      kevs[:title].should == "&amp;rft.atitle=WorkTitle"
      kevs[:date].should == "&amp;rft.date=2011-03-04"
      kevs[:volume].should == "&amp;rft.volume=11"
      kevs[:issue].should == "&amp;rft.issue=9"
      kevs[:start_page].should == "&amp;rft.spage=211"
      kevs[:end_page].should == "&amp;rft.epage=310"
    end

    it "with a publication returns some extra kevs" do
      authority = Factory.create(:publication, :name =&gt; 'AuthorityName')
      publication = Factory.create(:publication, :authority =&gt; authority)
      issn = Factory.create(:issn)
      publication.identifiers &lt;&lt; issn
      @work.publication = publication
      kevs = @work.open_url_kevs
      kevs[:source].should == "&amp;rft.jtitle=AuthorityName"
      kevs[:issn].should == "&amp;rft.issn=#{issn.name}"
    end
  end

  context "automatic field updates and initialization" do
    it "should call initialization methods when created" do
      work = Factory.build(:work)
      [:create_work_name_strings, :create_keywords, :create_tags].each do |method|
        work.should_receive(method)
      end
      work.save
    end

    it "should call update methods when saving" do
      work = Factory.create(:work)
      work.title_primary = work.title_primary + 'make a change'
      [:update_authorities, :update_scoring_hash, :update_archive_state, :update_machine_name, :deduplicate,
       :create_contributorships].each do |method|
        work.should_receive(method)
      end
      work.save
    end

    it "should automatically update publication and pubisher information when its publication is set" do
      work = Factory.create(:work)
      publisher = Factory.create(:publisher)
      publication = Factory.create(:publication, :publisher =&gt; publisher)
      publication.authority = publication
      work.publisher_id.should be_nil
      work.publication_id.should be_nil
      work.publication = publication
      work.save
      work.publication_id.should == publication.id
      work.publisher_id.should == publisher.id
    end

    it "should update the machine name when appropriate" do
      new_title = '  New --- Title , For this'
      work = Factory.create(:work)
      work.title_primary = new_title
      work.update_machine_name
      work.machine_name.should == 'new title for this'
    end

    context "updating archive status" do
      before(:each) do
        @work = Factory.create(:work)
      end

      it "should mark itself as archived if an archive time has been recorded" do
        @work.archived?.should be_false
        @work.archived_at = Time.now
        @work.save
        @work.archived?.should be_true
      end

      it "should mark itself as ready to archive if it has attachments" do
        @work.ready_to_archive?.should be_false
        @work.title_primary = @work.title_primary + 'force a change'
        @work.should_receive(:attachments).and_return([double('attachment')])
        @work.save
        @work.ready_to_archive?.should be_true
      end

      it "should revert to initial status if it is marked ready but has not attachements" do
        @work.is_ready_to_archive
        @work.save
        @work.ready_to_archive?.should be_false
      end

    end

    it "should be able to update its batch indexing status and save" do
      work = Factory.create(:work)
      work.batch_index.should == Work::NOT_TO_BE_BATCH_INDEXED
      work.set_for_index_and_save
      work.reload
      work.batch_index.should == Work::TO_BE_BATCH_INDEXED
      work.mark_indexed
      work.reload
      work.batch_index.should == Work::NOT_TO_BE_BATCH_INDEXED
    end

    it "should update its scoring hash" do
      work = Factory.create(:work)
      publication = Factory.create(:publication)
      keywords = 3.times.collect { Factory.create(:keyword) }
      name_strings = 4.times.collect { Factory.create(:name_string) }
      work.publication_date_year = 2008
      work.publication_date_month = 1
      work.publication_date_day = 2
      work.publication = publication
      work.set_keywords(keywords)
      work.name_strings = name_strings
      work.save
      work.scoring_hash.should == {:year =&gt; 2008, :publication_id =&gt; publication.id,
                                   :keyword_ids =&gt; keywords.collect { |kw| kw.id },
                                   :collaborator_ids =&gt; name_strings.collect { |ns| ns.id }}
    end

    #I've had a lot of trouble with how the various models interact and with their various callbacks
    #making it difficult to assure that I'm really testing what I should be here, so I've marked the
    #tests as pending, and the set up should be regarded as provisional as well.
    context "creating contributorships" do
      before(:each) do
        #create work with exising contributorship and work_name_string/pen_name needed for another one
        @work = Factory.create(:work)
        @contributorship = Factory.create(:contributorship, :work =&gt; @work, :role =&gt; @work.creator_role)
        @work_name_string = Factory.create(:work_name_string, :work =&gt; @work, :role =&gt; @work.contributor_role)
        @pen_name = Factory.build(:pen_name, :name_string =&gt; @work_name_string.name_string)
        #we need to intercept this or the pen_name will actually create the contributorship on save and we're trying
        #to test the work side
        @pen_name.should_receive(:set_contributorships)
        @pen_name.save
      end

      it "should create any new contributorships if it is accepted" do
        pending
      end

      it "should not create new contributorships if it is not accepted" do
        pending
      end
    end
  end

  context "dupe_key checking" do
    before(:each) do
      @work = Factory.create(:generic, :title_primary =&gt; 'Work Name', :publication_date_year =&gt; 2009,
                             :publication_date_month =&gt; 3, :publication_date_day =&gt; 21)
    end

    describe "title dupe key" do
      it "returns nil if it has no publication" do
        @work.title_dupe_key.should be_nil
      end

      it "returns nil if it has no publication authority" do
        @work.publication = Factory.create(:publication)
        @work.publication.should_receive(:authority).and_return(nil)
        @work.title_dupe_key.should be_nil
      end

      it "returns a solr-like string if it has a publication authority" do
        @work.publication = Factory.create(:publication)
        @work.title_dupe_key.should == ['work name', '2009', @work.publication.authority.machine_name].join("||")
      end
    end

    describe "name_string dupe key" do
      it "returns nil without any name strings" do
        @work.name_string_dupe_key.should be_nil
      end

      it "returns a solr like string with name_strings" do
        name_string = Factory.create(:name_string, :name =&gt; 'Name String Name')
        Factory.create(:work_name_string, :work =&gt; @work, :name_string =&gt; name_string)
        @work.name_strings(true).should == [name_string]
        @work.name_string_dupe_key.should == ['name string name', '2009', 'Generic', 'work name'].join('||')
      end
    end
  end
  
  context 'merge duplicates' do
    before(:each) do
      @work = Factory.create(:work, :title_primary =&gt; 'Work Title 1',
                :abstract =&gt; 'The abstract of my work.', :volume =&gt; '1')
      name_string = Factory.create(:name_string, :name =&gt; 'Name String Name')
        Factory.create(:work_name_string, :work =&gt; @work, :name_string =&gt; name_string)                
      @work2 = @work.clone
      @work2.save    
    end
    
    it 'calculates richness of a work' do
      @work.richness.should &gt; 10
    end
    
    it 'sorts possible duplicates in order of descending richness' do

      @work.is_accepted
      @work2.is_accepted
      @work.save
      @work2.save
      @work.should be_accepted
      @work2.should be_accepted

      
      @work.sort_dupes_by_richness.should include(@work, @work2)
      
      @work.update_attributes(:issue =&gt; '1')
      
      @work.sort_dupes_by_richness.should eq([@work, @work2])
      
      @work2.update_attributes(:issue =&gt; '1', :links =&gt; 'http://example.com/work2')
    
      @work.sort_dupes_by_richness.should eq([@work2, @work])
    end
    
    it 'matches works that have identical non-system attributes' do
      @work.merge_equal?(@work2).should be true
    end
    
    it 'merges duplicate works and their associations' do
      #r = @work.richness
      #r2 = @work2.richness
     # @work.merge_duplicates.should
    end        

  end

  it "can create a unique solr id" do
    work = Factory.create(:work)
    work.solr_id.should == "Work-#{work.id}"
  end

  it 'has specified initial states' do
    work = Factory.create(:work)
    work.in_process?
    work.has_init_archive_status?
  end

  context 'setting publication and publisher information' do

    it 'works from a hash' do
      @work = Factory.create(:work)
      @work.set_publication_info(:name =&gt; 'Publication Name', :publisher_name =&gt; 'Publisher Name', :issn_isbn =&gt; ISSN.random)
      @work.publisher.should == Publisher.find_by_name('Publisher Name')
      @work.initial_publisher_id.should == @work.publisher.id
      @work.publication.should == Publication.find_by_name('Publication Name')
      @work.initial_publication_id.should == @work.publication.id
    end

    it 'works without an issn' do
      @work = Factory.create(:work)
      @publisher = Factory.create(:publisher, :name =&gt; 'Publisher')
      @work.set_publication_from_name('Publication', nil, @publisher)
      @work.publication.should == Publication.find_by_name_and_initial_publisher_id('Publication', @publisher.id)
      @work.initial_publication_id.should == @work.publication.id
    end

    it 'works without an issn or publisher' do
      @work = Factory.create(:work)
      @work.set_publication_from_name('Publication', nil, nil)
      @work.publication.should == Publication.find_by_name('Publication')
      @work.initial_publication_id.should == @work.publication.id
    end
  end

  context "work name strings" do
    it "can be set from a hash for an existing record" do
      work = Factory.create(:generic)
      work.work_name_strings &lt;&lt; (old_name_string = Factory.create(:work_name_string))
      work.set_work_name_strings([{:name =&gt; 'Peters, Pete', :role =&gt; 'Creator'},
                                  {:name =&gt; 'Josephs, Joe', :role =&gt; 'Contributor'}])
      work.work_name_strings.size.should == 2
      work.work_name_strings.member?(old_name_string).should be_false
    end

    it "can be set from a hash for a new record" do
      work = Factory.build(:generic)
      work.set_work_name_strings([{:name =&gt; 'Peters, Pete', :role =&gt; 'Creator'},
                                  {:name =&gt; 'Josephs, Joe', :role =&gt; 'Contributor'}])
      work.work_name_strings(true).should be_empty
      work.save
      work.work_name_strings.size.should == 2
    end
  end

  context "tags" do
    it "sets from a list of tags for an existing work" do
      work = Factory.create(:generic)
      work.tags &lt;&lt; (old_tag = Factory.create(:tag))
      new_tags = 3.times.collect { Factory.create(:tag) }
      work.set_tags(new_tags)
      work.tags(true).should_not include(old_tag)
      work.tags.to_set.should == new_tags.to_set
    end

    it "sets from a list of tags for a new work" do
      work = Factory.build(:generic)
      new_tags = 3.times.collect { Factory.build(:tag) }
      work.set_tags(new_tags)
      work.tags(true).should be_empty
      work.save
      work.tags(true).size.should == 3
    end

    it "sets from a list of tag names" do
      work = Factory.build(:generic)
      work.set_tag_strings ['Pete', 'Joe', 'Ack']
      work.tags(true).size.should == 3
    end
  end

  context "keywords" do
    it "sets from a list of keywords for an existing work" do
      work = Factory.create(:generic)
      work.keywords &lt;&lt; (old_keyword = Factory.create(:keyword))
      new_keywords = 3.times.collect { Factory.create(:keyword) }
      work.set_keywords(new_keywords)
      work.keywords(true).should_not include(old_keyword)
      work.keywords.to_set.should == new_keywords.to_set
    end

    it "sets from a list of keywords for a new work" do
      work = Factory.build(:generic)
      new_keywords = 3.times.collect { Factory.build(:keyword) }
      work.set_keywords(new_keywords)
      work.keywords(true).should be_empty
      work.save
      work.keywords(true).size.should == 3
    end

    it "sets from a list of keyword strings" do
      work = Factory.build(:generic)
      work.set_keyword_strings ['Pete', 'Joe', 'Ack']
      work.keywords(true).size.should == 3
    end
  end

  it "can convert a string as found in its types array to a work subclass" do
    type_1 = "Conference Proceeding (Whole)"
    type_2 = "Dissertation / Thesis"
    [type_1, type_2].each { |type| Work.types.include?(type) }
    Work.type_to_class(type_1).should == ConferenceProceedingWhole
    Work.type_to_class(type_2).should == DissertationThesis
  end

  context 'operations with hash data' do
    context 'creation' do
      it "can create a subclass instance from hash data" do
        expect { Work.create_from_hash(:klass =&gt; 'Generic', :title_primary =&gt; 'Title') }.to change { Generic.count }.by(1)
      end

      it "raises an error if attempting to create an invalid subclass" do
        expect { Work.create_from_hash(:klass =&gt; 'Object') }.to raise_error(NameError)
      end
    end

    context 'role identification' do
      before(:each) { @work = Factory.create(:performance) }
      it "should be able to return a specific creator role in place of 'Author'" do
        @work.denormalize_role('Author').should == 'Director'
      end

      it "should be able to return a specific contributor role in place of 'Editor'" do
        @work.denormalize_role('Editor').should == 'Musician'
      end

      it "should return a role unchanged if it is neither Author or Editor" do
        @work.denormalize_role('OtherRole').should == 'OtherRole'
      end
    end

    it "should be able to clean the hash of non-work related keys" do
      keys = [:klass, :work_name_strings, :publisher, :publication, :issn_isbn, :keywords, :source, :external_id]
      hash = Hash.new.tap do |h|
        keys.each do |key|
          h[key] = key.to_s
        end
      end
      work = Factory.create(:work)
      work.delete_non_work_data(hash)
      hash.size.should == 0
    end

    context 'publication name' do
      before(:each) do
        @hash = {:title_primary =&gt; "Title Primary", :title_secondary =&gt; "Title Secondary", :publication =&gt; 'Publication'}
      end

      it "uses title_primary for some classes" do
        work = Factory.build(:book_whole)
        work.publication_name_from_hash(@hash).should == 'Title Primary'
      end

      it "uses title_secondary for some classes" do
        work = Factory.build(:report)
        work.publication_name_from_hash(@hash).should == 'Title Secondary'
      end

      it "uses publication for some classes" do
        work = Factory.build(:book_review)
        work.publication_name_from_hash(@hash).should == 'Publication'
      end

      it "uses nil for some classes" do
        work = Factory.build(:artwork)
        work.publication_name_from_hash(@hash).should be_nil
      end

      it "uses 'Unknown' if the right hash key is not set" do
        work = Factory.build(:monograph)
        work.publication_name_from_hash({}).should == 'Unknown'
      end
    end
  end

  describe 'orphan detection' do
    def work_with_contributorships(*states)
      title = states.blank? ? 'None' : states.join(' ')
      Factory.create(:work, :title_primary =&gt; title).tap do |work|
        states.each do |state|
          Factory.create(:contributorship, :work =&gt; work).send("#{state}_contributorship")
        end
      end
    end

    before(:each) do
      @works = [work_with_contributorships(), work_with_contributorships(:verify), work_with_contributorships(:deny),
                work_with_contributorships(:verify, :verify), work_with_contributorships(:deny, :deny),
                work_with_contributorships(:verify, :deny)]
      @work_no_contribs, @work_verified_contrib, @work_denied_contrib, @work_verified_contribs,
          @work_denied_contribs, @work_mixed_contribs = @works
    end

    it 'should be able to identify works without contributorships as orphans' do
      Work.orphans_no_contributorships.should == [@work_no_contribs]
    end

    it 'should be able to identity work with exclusively denied contributorships as orphans' do
      Work.orphans_denied_contributorships.to_set.should == [@work_denied_contrib, @work_denied_contribs].to_set
    end

    it 'should be able to aggregate all orphans' do
      Work.orphans.to_set.should == [@work_no_contribs, @work_denied_contrib, @work_denied_contribs].to_set
    end

  end

  describe "publication date" do
    before(:each) do
      @work = Factory.build(:work)
    end

    def set_date(year = nil, month = nil, day = nil)
      @work.publication_date_year = year
      @work.publication_date_month = month
      @work.publication_date_day = day
    end

    it "should be valid if all the date fields are blank" do
      @work.should be_valid
    end

    it "should be valid if it only has a year" do
      set_date(2011)
      @work.should be_valid
    end

    it "should be valid if it has a year and a valid month but no day" do
      set_date(2011, 5)
      @work.should be_valid
    end

    it "should be invalid if it has a year and an invalid month" do
      set_date(2011, 13)
      @work.should_not be_valid
    end

    it "should be valid if it has a year, valid month, and valid day" do
      set_date(2011, 4, 12)
      @work.should be_valid
    end

    it "should be invalid if it has a year, valid month, and invalid day" do
      set_date(2011, 2, 29)
      @work.should_not be_valid
    end

    it "should be invalid if it has a year and day but no month" do
      set_date(2011, nil, 1)
      @work.should_not be_valid
    end

    it "should be invalid if it has a month but lacks a year" do
      set_date(nil, 1)
      @work.should_not be_valid
    end

    it "should be invalid if it has a day but lacks a month" do
      set_date(2011, nil, 1)
      @work.should_not be_valid
    end

    it "should be invalid if it has a day but lacks a year" do
      set_date(nil, nil, 1)
      @work.should_not be_valid
    end
  end
end
</pre></body></html>