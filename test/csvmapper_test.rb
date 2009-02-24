require File.dirname(__FILE__) + '/test_helper'


shared_context 'CSVMapped' do
  
  it 'should respond to parse' do
    @klass.should.respond_to(:parse)
  end
  
  context '#parse' do
    before { @collection = @klass.parse(@csv)}
    it 'returns array of instances of correct class' do
      @collection.class.should  == Array
      @collection.first.class.should == @klass
    end
  end
  
  context 'instances' do
    before{ @instance = @klass.new }
    
    specify 'have a getter for every column' do
      @instance_expectations.each do |expectations|
        expectations.each do |name, value|
          @instance.should.respond_to(name.to_s)
        end
      end
    end
    
    specify 'have a setter for every column' do
      @instance_expectations.each do |expectations|
        expectations.each do |name, value|
          @instance.should.respond_to("#{name}=")
        end
      end
    end
    
    context 'returned by #parse' do
      
      before { @instances = @klass.parse(@csv).first(@instance_expectations.size)}
      
      specify 'have the correct types and values' do
        @instance_expectations.each_with_index do |expectations, ix|
          expectations.each do |name, value|
            var = @instances[ix].send("#{name}")
          
            var.class.should == value.class
            var.should == value
          end
        end
      end
    end
  end
end

module Shop
  class Product
    include CSVMapper
    
    column(:category, 'product_category', Integer)
    column(:created, 2, Date)
    column(:price, 'product_price', Float)
    column(:naam, 'name'){|name| "Mr. #{name}"}
  end
end

context 'simple class' do
  before{
    @klass  = Shop::Product
    @csv =<<-CSV.gsub(/^ +/,'')
      name,product_price,created,non_used_column,product_category
      Brown,1000.0,13-12-2008,garbage,1
      Pink,2000.0,14-12-2008,garbage2,2
    CSV

    @instance_expectations = [
                                {
                                  :price  => 1000.0,
                                  :created => Date.parse('13-12-2008'),
                                  :naam   => 'Mr. Brown',
                                  :category => 1
                                },
                                {
                                  :naam   => 'Mr. Pink',
                                  :price  => 2000.0,
                                  :created => Date.parse('14-12-2008'),
                                  :category => 2
                                }
                              ]
  }
  behaves_like 'CSVMapped'
  
end

class Transaction
  include CSVMapper
  
  # Price Paid,Stock Symbol,Regulator,Name,City,FDIC Number,Transaction Type,State,Program,Pricing Mechanism,Type of Institution,Total Assets,Date,OTS Number,Description
  
  column :symbol, 'Stock Symbol'
  column(:price_in_cents, 'Price Paid') {|raw| raw.to_f * 100 rescue 0.0 }
  column :description, 'Description'
  column :ots,  'OTS Number'
  column :fdic, 'FDIC Number', Integer
end

context 'some more csv' do
  before {
    @klass = Transaction
    @csv  = File.open(File.dirname(__FILE__) + '/fixtures/large.csv').read

    @instance_expectations = [
                        {
                          :symbol  =>  'STT',
                          :price_in_cents =>  200000000000.0,
                          :description  =>  'Preferred Stock w/Warrants',
                          :ots  => '',
                          :fdic => 1111435
                        },
                        {
                          :symbol  =>  'C',
                          :price_in_cents =>  2500000000000.0,
                          :description  =>  'Preferred Stock w/Warrants',
                          :ots  => '',
                          :fdic => 1951350
                        }
                    ]
  }
  
  behaves_like 'CSVMapped'
end

require 'activerecord'
require 'sqlite3'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3",:dbfile  => ":memory:")

ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :ar_products do |t|
    t.column :name, :string
    t.column :price, :float
    
    t.timestamps
  end
end

class ARProduct < ActiveRecord::Base
  include CSVMapper
  
  attr_protected :name
  
  column :name
  column :price, 'product_price', Float
  column :uid, 'product_uid', Integer
  column(:created_at, 'product_created', DateTime)
end

context 'active record class' do
  DBColumn = ActiveRecord::ConnectionAdapters::Column
  before {
    # stub(ARProduct).table_exists?{ true }
    # stub(ARProduct).columns { [
    #                             DBColumn.new("name",  nil, "string", false),
    #                             DBColumn.new("price", nil, "float", false)
    #                           ] }
    
    @klass = ARProduct
    @csv =<<-CSV.gsub(/^ +/,'')
      name,product_price,product_created,product_uid,product_category
      naam,1000.0,13-12-2008 13:00,1200,1
      line2,2000.0,14-12-2008 14:00,1201,2
    CSV

    @instance_expectations = [{
                                :name=>'naam', 
                                :price=>1000.0, 
                                :uid=>1200, 
                                :created_at=>DateTime.parse('13-12-2008 13:00')}
                              ]
  }
  behaves_like 'CSVMapped'
end