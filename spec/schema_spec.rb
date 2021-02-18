# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/reasoner/schema'

describe RDF::Reasoner::Schema do
  before(:all) {RDF::Reasoner.apply(:schema, :rdfs)}
  let(:ex) {RDF::URI("http://example/")}

  describe :domainIncludes do
    {
      RDF::Vocab::SCHEMA.about => [RDF::Vocab::SCHEMA.CreativeWork].map(&:pname),
    }.each do |cls, entails|
      describe cls.pname do
        specify {expect(cls.domain_includes.map(&:pname)).to include(*entails)}
        specify {expect(cls.domainIncludes.map(&:pname)).to include(*entails)}
      end
    end

    {
      RDF::Vocab::SCHEMAS.about => [RDF::Vocab::SCHEMAS.CreativeWork].map(&:pname),
    }.each do |cls, entails|
      describe cls.pname do
        specify {expect(cls.properties[RDF::Vocab::SCHEMAS.domainIncludes].map(&:pname)).to include(*entails)}
      end
    end
  end

  describe :rangeIncludes do
    {
      RDF::Vocab::SCHEMA.about => [RDF::Vocab::SCHEMA.Thing].map(&:pname),
      RDF::Vocab::SCHEMA.event => [RDF::Vocab::SCHEMA.Event].map(&:pname),
    }.each do |cls, entails|
      describe cls.pname do
        specify {expect(cls.range_includes.map(&:pname)).to include(*entails)}
        specify {expect(cls.rangeIncludes.map(&:pname)).to include(*entails)}
      end
    end

    {
      RDF::Vocab::SCHEMAS.about => [RDF::Vocab::SCHEMAS.Thing].map(&:pname),
      RDF::Vocab::SCHEMAS.event => [RDF::Vocab::SCHEMAS.Event].map(&:pname),
    }.each do |cls, entails|
      describe cls.pname do
        specify {expect(Array(cls.properties[RDF::Vocab::SCHEMAS.rangeIncludes]).map(&:pname)).to include(*entails)}
      end
    end
  end

  describe :domain_compatible? do
    let!(:queryable) {
      RDF::Graph.new do |g|
        g << RDF::Statement(ex+"a", RDF.type, RDF::Vocab::SCHEMA.Person)
        g << RDF::Statement(ex+"a", RDF.type, RDF::Vocab::SCHEMAS.Person)
      end
    }
    context "domain and no provided types" do
      it "uses entailed types of resource" do
        expect(RDF::Vocab::SCHEMA.familyName).to be_domain_compatible(ex+"a", queryable)
      end

      it "uses entailed types of resource (https)" do
        expect(RDF::Vocab::SCHEMAS.familyName).to be_domain_compatible(ex+"a", queryable)
      end
    end

    it "returns true with no domain and no type" do
      expect(RDF::Vocab::SCHEMA.dateCreated).to be_domain_compatible(ex+"b", queryable)
    end

    it "returns true with no domain and no type (https)" do
      expect(RDF::Vocab::SCHEMAS.dateCreated).to be_domain_compatible(ex+"b", queryable)
    end

    it "uses supplied types" do
      expect(RDF::Vocab::SCHEMA.dateCreated).not_to be_domain_compatible(ex+"a", queryable)
      expect(RDF::Vocab::SCHEMA.dateCreated).to be_domain_compatible(ex+"a", queryable, types: [RDF::Vocab::SCHEMA.CreativeWork])
    end

    it "uses supplied types (https)" do
      expect(RDF::Vocab::SCHEMAS.dateCreated).not_to be_domain_compatible(ex+"a", queryable)
      expect(RDF::Vocab::SCHEMAS.dateCreated).to be_domain_compatible(ex+"a", queryable, types: [RDF::Vocab::SCHEMAS.CreativeWork])
    end

    context "domain violations" do
      {
        "subject of wrong type" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Person; schema:acceptedOffer [a schema:Offer] .
        ),
        "subject of wrong type (https)" => %(
          @prefix schemas: <https://schema.org/> .
          <foo> a schemas:Person; schemas:acceptedOffer [a schemas:Offer] .
        ),
      }.each do |name, input|
        it name do
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(input)
          statement = graph.to_a.reject {|s| s.predicate == RDF.type}.first
          expect(RDF::Vocabulary.find_term(statement.predicate)).not_to be_domain_compatible(statement.object, graph)
        end
      end
    end
  end

  describe :range_compatible? do
    context "objects in range" do
      {
        "object of right type" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Order; schema:acceptedOffer [a schema:Offer] .
        ),
        "object range with plain literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Order; schema:acceptedOffer "foo" .
        ),
        "schema:URL with language-tagged literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Thing; schema:url "http://example/"@en .
        ),
        "schema:URL with an untyped URI resource" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Thing; schema:url <http://example/> .
        ),
        "schema:URL with a typed URI resource" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Thing; schema:url <http://example/> . <http://example/> a schema:Organization .
        ),
        "schema:Text with an untyped URI resource" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Thing; schema:name <http://example/> .
        ),
        "schema:Height with anonymous structured value" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:height [ a schema:Distance; schema:name "20 3/4 inches" ] .
        ),
        "schema:Height with identified structured value" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:height <dist> . <dist> a schema:Distance; schema:name "20 3/4 inches" .
        ),
        "schema:CreativeWork with itemListElement (IRI)" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:itemListElement <obj> . <obj> a schema:CreativeWork .
        ),
        "schema:CreativeWork with itemListElement (BNode)" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:itemListElement [ a schema:CreativeWork ] .
        ),
        "text literal with itemListElement" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:itemListElement "Foo" .
        ),
      }.each do |name, input|
        it name do
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(input)
          statement = graph.to_a.reject {|s| s.predicate == RDF.type}.first
          expect(RDF::Vocabulary.find_term(statement.predicate)).to be_range_compatible(statement.object, graph)
        end

        it "#{name.sub('schema:', 'schemas:')} (https)" do
          input = input.
            gsub('http://schema.org', 'https://schema.org').
            gsub('schema:', 'schemas:')
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(input)
          statement = graph.to_a.reject {|s| s.predicate == RDF.type}.first
          expect(RDF::Vocabulary.find_term(statement.predicate)).to be_range_compatible(statement.object, graph)
        end
      end

      context "ISO 8601" do
        %w(
          2009-12T12:34
          2009
          2009-05-19
          2009-05-19
          20090519
          2009123
          2009-05
          2009-123
          2009-222
          2009-001
          2009-W01-1
          2009-W51-1
          2009-W511
          2009-W33
          2009W511
          2009-05-19
          2009-05-19_00:00
          2009-05-19_14
          2009-05-19_14:31
          2009-05-19_14:39:22
          2009-05-19T14:39Z
          2009-W21-2
          2009-W21-2T01:22
          2009-139
          2009-05-19_14:39:22-06:00
          2009-05-19_14:39:22+0600
          2009-05-19_14:39:22-01
          20090621T0545Z
          2007-04-06T00:00
          2007-04-05T24:00

          2010-02-18T16:23:48.5
          2010-02-18T16:23:48,444
          2010-02-18T16:23:48,3-06:00
          2010-02-18T16:23.4
          2010-02-18T16:23,25
          2010-02-18T16:23.33+0600
          2010-02-18T16.23334444
          2010-02-18T16,2283
          2009-05-19_143922.500
          2009-05-19_1439,55
        ).each do |date|
          it "recognizes #{date.sub('_', ' ')}" do
            expect(RDF::Vocab::SCHEMA.startDate).to be_range_compatible(RDF::Literal(date.sub('_', ' ')), [])
            expect(RDF::Vocab::SCHEMAS.startDate).to be_range_compatible(RDF::Literal(date.sub('_', ' ')), [])
          end
        end

        %w(
          200905
          2009367
          2009-
          2007-04-05T24:50
          2009-000
          2009-M511
          2009M511
          2009-05-19T14a39r
          2009-05-19T14:3924
          2009-0519
          2009-05-1914:39
          2009-05-19_14:
          2009-05-19r14:39
          2009-05-19_14a39a22
          200912-01
          2009-05-19_14:39:22+06a00

          2009-05-19_146922.500
          2010-02-18T16.5:23.35:48
          2010-02-18T16:23.35:48
          2010-02-18T16:23.35:48.45
          2009-05-19_14.5.44
          2010-02-18T16:23.33.600
          2010-02-18T16,25:23:48,444
        ).each do |date|
          it "does not recognize #{date.sub('_', ' ')}" do
            expect(RDF::Vocab::SCHEMA.startDate).not_to be_range_compatible(RDF::Literal(date.sub('_', ' ')), [])
            expect(RDF::Vocab::SCHEMAS.startDate).not_to be_range_compatible(RDF::Literal(date.sub('_', ' ')), [])
          end
        end
      end
    end

    context "object range violations" do
      {
        "object of wrong type" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Order; schema:acceptedOffer [a schema:Thing] .
        ),
        "object range with typed literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Order; schema:acceptedOffer "foo"^^schema:URL .
        ),
        "literal range with BNode" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:name _:bar .
        ),
        "literal range with URI (not schema:URL or schema:Text)" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:startDate <bar> .
        ),
        "schema:Text with a typed URI resource" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Thing; schema:name <http://example/> . <http://example/> a schema:Person .
        ),
      }.each do |name, input|
        it name do
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(input)
          statement = graph.to_a.reject {|s| s.predicate == RDF.type}.first
          expect(RDF::Vocabulary.find_term(statement.predicate)).not_to be_range_compatible(statement.object, graph)
        end

        it "#{name.sub('schema:', 'schemas:')} (https)" do
          input = input.
            gsub('http://schema.org', 'https://schema.org').
            gsub('schema:', 'schemas:')
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(input)
          statement = graph.to_a.reject {|s| s.predicate == RDF.type}.first
          expect(RDF::Vocabulary.find_term(statement.predicate)).not_to be_range_compatible(statement.object, graph)
        end
      end
    end

    context "literal range violations" do
      {
        "schema:Number expected with conforming plain literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:amountOfThisGood "bar" .
        ),
        "schema:Integer expected with conforming plain literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:answerCount "bar" .
        ),
        "schema:Date expected with conforming plain literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:birthDate "bar" .
        ),
        "schema:DateTime expected with conforming plain literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:checkinTime "bar" .
        ),
        "schema:Text with datatyped literal" => %(
          @prefix schema: <http://schema.org/> .
          @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
          <foo> a schema:Thing; schema:recipeIngredient "foo"^^xsd:token .
        ),
        "schema:URL with non-conforming plain literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:Thing; schema:url "foo" .
        ),
        "schema:Boolean with non-conforming plain literal" => %(
          @prefix schema: <http://schema.org/> .
          <foo> a schema:CreativeWork; schema:isFamilyFriendly "bar" .
        ),
        "date with itemListElement" => %(
          @prefix schema: <http://schema.org/> .
          <foo> schema:itemListElement "2016-08-22"^^schema:Date .
        ),
      }.each do |name, input|
        it name do
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(input)
          statement = graph.to_a.reject {|s| s.predicate == RDF.type}.first
          expect(RDF::Vocabulary.find_term(statement.predicate)).not_to be_range_compatible(statement.object, graph)
        end

        it "#{name.sub('schema:', 'schemas:')} (https)" do
          input = input.
            gsub('http://schema.org', 'https://schema.org').
            gsub('schema:', 'schemas:')
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(input)
          statement = graph.to_a.reject {|s| s.predicate == RDF.type}.first
          expect(RDF::Vocabulary.find_term(statement.predicate)).not_to be_range_compatible(statement.object, graph)
        end
      end
    end
  end


  describe "Roles" do
    {
      "Cryptography Users" => {
        input: %(
          @prefix schema: <http://schema.org/> .
          <http://example/foo> a schema:Organization;
            schema:name "Cryptography Users";
            schema:member [
              a schema:OrganizationRole, schema:Role;
              schema:member [
                a schema:Person;
                schema:name "Alice"
              ];
              schema:startDate "1977"
            ] .
        ),
        predicate: RDF::Vocab::SCHEMA.member,
        result: :domain_range
      },
      "Cryptography Users (not domain)" => {
        input: %(
          @prefix schema: <http://schema.org/> .
          <http://example/foo> a schema:Organization;
            schema:name "Cryptography Users";
            schema:alumni [
              a schema:OrganizationRole, schema:Role;
              schema:member [
                a schema:Person;
                schema:name "Alice"
              ];
              schema:startDate "1977"
            ] .
        ),
        predicate: RDF::Vocab::SCHEMA.member,
        result: :not_domain
      },
      "Cryptography Users (not range)" => {
        input: %(
          @prefix schema: <http://schema.org/> .
          <http://example/foo> a schema:Organization;
            schema:name "Cryptography Users";
            schema:alumni [
              a schema:OrganizationRole, schema:Role;
              schema:member [
                a schema:Person;
                schema:name "Alice"
              ];
              schema:startDate "1977"
            ] .
        ),
        predicate: RDF::Vocab::SCHEMA.alumni,
        result: :not_range
      },
      "University of Cambridge" => {
        input: %(
          @prefix schema: <http://schema.org/> .
          <http://example/foo> a schema:CollegeOrUniversity;
            schema:name "University of Cambridge";
            schema:sameAs <http://en.wikipedia.org/wiki/University_of_Cambridge>;
            schema:alumni [
              a schema:OrganizationRole, schema:Role;
              schema:alumni [
                a schema:Person;
                schema:name "Delia Derbyshire";
                schema:sameAs <http://en.wikipedia.org/wiki/Delia_Derbyshire>
              ];
              schema:startDate "1957"
            ] .
        ),
        predicate: RDF::Vocab::SCHEMA.alumni,
        result: :domain_range
      },
      "Delia Derbyshire" => {
        input: %(
          @prefix schema: <http://schema.org/> .
          <http://example/foo> a schema:Person;
            schema:name "Delia Derbyshire";
            schema:sameAs <http://en.wikipedia.org/wiki/Delia_Derbyshire>;
            schema:alumniOf [
              a schema:OrganizationRole, schema:Role;
              schema:alumniOf [
                a schema:CollegeOrUniversity;
                schema:name "University of Cambridge";
                schema:sameAs <http://en.wikipedia.org/wiki/University_of_Cambridge>
              ];
              schema:startDate "1957"
            ] .
        ),
        predicate: RDF::Vocab::SCHEMA.alumniOf,
        result: :domain_range
      },
      "San Francisco 49ers" => {
        input: %(
          @prefix schema: <http://schema.org/> .
          <http://example/foo> a schema:SportsTeam;
            schema:name "San Francisco 49ers";
            schema:member [
              a schema:PerformanceRole, schema:Role;
              schema:member [
                a schema:Person;
                schema:name "Joe Montana"
              ];
              schema:startDate "1979";
              schema:endDate "1992";
              schema:namedPosition "Quarterback"
            ] .
        ),
        predicate: RDF::Vocab::SCHEMA.member,
        result: :domain_range
      },
    }.each do |name, params|
      context name do
        let(:graph) {RDF::Graph.new << RDF::Turtle::Reader.new(params[:input])}
        let(:resource) {graph.first_subject(predicate: RDF.type, object: RDF::Vocab::SCHEMA.Role)}

        it "allows role in domain", if: params[:result] == :domain_range do
          expect(params[:predicate]).to be_domain_compatible(resource, graph)
        end

        it "allows role in range", if: params[:result] == :domain_range  do
          expect(params[:predicate]).to be_range_compatible(resource, graph)
        end

        it "does not allow role in domain", if: params[:result] == :not_domain do
          expect(params[:predicate]).not_to be_domain_compatible(resource, graph)
        end

        it "does not allow role in range", if: params[:result] == :not_range do
          expect(params[:predicate]).not_to be_range_compatible(resource, graph)
        end
      end
    end
  end

  describe "Lists" do
    {
      "Creator list" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <http://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first [a schema:Person; schema:name "John Doe"];
              rdf:rest rdf:nil
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMA.creator,
        result:     :range
      },
      "Creator list (https)" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <https://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first [a schema:Person; schema:name "John Doe"];
              rdf:rest rdf:nil
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMAS.creator,
        result:     :range
      },
      "Creator list with string value" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <http://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first "John Doe";
              rdf:rest rdf:nil
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMA.creator,
        result:     :range
      },
      "Creator list with string value (https)" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <https://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first "John Doe";
              rdf:rest rdf:nil
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMAS.creator,
        result:     :range
      },
      "Creator list (single invalid value)" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <http://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first [a schema:CreativeWork; schema:name "Website"];
              rdf:rest rdf:nil
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMA.creator,
        result:     :not_range
      },
      "Creator list (single invalid value) (https)" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <https://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first [a schema:CreativeWork; schema:name "Website"];
              rdf:rest rdf:nil
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMAS.creator,
        result:     :not_range
      },
      "Creator list (mixed valid/invalid)" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <http://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first [a schema:Person; schema:name "John Doe";];
              rdf:rest [
                a rdf:List;
                rdf:first [a schema:CreativeWork; schema:name "Website"];
                rdf:rest rdf:nil
              ]
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMA.creator,
        result:     :not_range
      },
      "Creator list (mixed valid/invalid) (https)" => {
        input: %(
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          @prefix schema: <https://schema.org/> .
          <http://example/Review> a schema:Review;
            schema:creator [
              a rdf:List;
              rdf:first [a schema:Person; schema:name "John Doe";];
              rdf:rest [
                a rdf:List;
                rdf:first [a schema:CreativeWork; schema:name "Website"];
                rdf:rest rdf:nil
              ]
            ] .
        ),
        resource:   RDF::URI("http://example/Review"),
        predicate:  RDF::Vocab::SCHEMAS.creator,
        result:     :not_range
      },
    }.each do |name, params|
      context name do
        let(:graph) {RDF::Graph.new << RDF::Turtle::Reader.new(params[:input])}
        let(:resource) {params[:resource]}
        let(:predicate) {params[:predicate]}
        let(:list) {graph.first_object(subject: resource, predicate: predicate)}

        it "allows list in range", if: params[:result] == :range do
          expect(predicate).to be_range_compatible(list, graph)
        end

        it "does not allow list in range", if: params[:result] == :not_range do
          expect(predicate).not_to be_range_compatible(list, graph)
        end
      end
    end
  end

end
